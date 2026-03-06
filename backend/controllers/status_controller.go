package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

const activeWatchingUsersKey = "watching:active_users"

// SetWatchStatus — Kullanıcının izleme durumunu belirler
// userId JWT token'dan alınır (manipülasyon engeli)
// Redis'te şu key'ler kullanılır:
//   - watching:<userId>       → JSON (film bilgileri, TTL: 15 dakika)
//   - movie:<tmdbId>:watchers → Set (bu filmi izleyen userId listesi, TTL: 15 dakika)
//   - watching:active_users   → Set (herhangi bir şeyi aktif izleyen kullanıcılar)
//
// Ayrıca MongoDB'deki kullanıcının watch_history alanına eşsiz olarak eklenir.
func SetWatchStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		// userId ve username JWT middleware'den geliyor
		userId, ok := mustUserID(c)
		if !ok {
			return
		}
		username := c.GetString("username")

		var input models.WatchStatus
		if err := c.ShouldBindJSON(&input); err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "Geçersiz veri", err.Error())
			return
		}

		// Önceki izleme durumunu temizle (varsa)
		clearPreviousStatus(ctx, userId)

		// İzleme bilgilerini JSON olarak hazırla
		input.UserID = userId
		input.Username = username
		input.StartedAt = time.Now()

		statusJSON, _ := json.Marshal(input)

		// Redis'e yaz
		watchKey := fmt.Sprintf("watching:%s", userId)
		movieKey := fmt.Sprintf("movie:%d:watchers", input.TmdbID)

		pipe := config.RedisClient.Pipeline()
		pipe.Set(ctx, watchKey, statusJSON, 15*time.Minute) // 15 dakika TTL
		pipe.SAdd(ctx, movieKey, userId)                    // İzleyenler set'ine ekle
		pipe.Expire(ctx, movieKey, 15*time.Minute)          // Set'e de TTL koy
		pipe.SAdd(ctx, activeWatchingUsersKey, userId)      // Aktif izleyiciler set'ine ekle
		_, err := pipe.Exec(ctx)

		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "STATUS_SAVE_FAILED", "İzleme durumu kaydedilemedi", err.Error())
			return
		}

		// --------------------------------------------------------------------------
		// MONGODB: İzleme Geçmişini Güncelle
		// --------------------------------------------------------------------------
		objectID, err := primitive.ObjectIDFromHex(userId)
		if err == nil {
			userCollection := config.GetCollection(config.DB, "users")
			historyItem := models.WatchHistoryItem{
				TmdbID:     input.TmdbID,
				MovieName:  input.MovieName,
				PosterPath: input.PosterPath,
				WatchedAt:  input.StartedAt,
			}

			// Eğer bu filmi daha önce geçmişe eklemediyse (tmdb_id ne input.TmdbID) ekle
			// Bu sayede her film listede sadece bir kez kalır ve İLK izleme sırası korunur
			// OPTIMIZED: $slice ile history boyutunu sınırla (maks 50 item)
			filter := bson.M{
				"_id":                   objectID,
				"watch_history.tmdb_id": bson.M{"$ne": input.TmdbID},
			}
			update := bson.M{
				"$push": bson.M{
					"watch_history": bson.M{
						"$each":     []interface{}{historyItem},
						"$position": 0,
						"$slice":    -50, // En son 50 item'ı tut
					},
				},
			}

			_, mongoErr := userCollection.UpdateOne(ctx, filter, update)
			if mongoErr != nil {
				// MongoDB hatası ana akışı bozmasın ama loglayalım
				fmt.Printf("[STATUS] Watch history sync error: %v\n", mongoErr)
			}
		}
		// --------------------------------------------------------------------------

		c.JSON(http.StatusOK, gin.H{
			"message":   "İzleme durumu güncellendi!",
			"movieName": input.MovieName,
			"startedAt": input.StartedAt,
		})
	}
}

// GetActiveWatchers — Belirli bir filmi izleyenleri listeler
func GetActiveWatchers() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		viewerIDHex, ok := mustUserID(c)
		if !ok {
			return
		}
		viewerID, ok := parseObjectIDOrBadRequest(c, viewerIDHex, "kullanıcı kimliği")
		if !ok {
			return
		}

		tmdbIdStr := c.Query("tmdbId")
		tmdbID, err := strconv.Atoi(tmdbIdStr)
		if err != nil || tmdbID <= 0 {
			errorResponse(c, http.StatusBadRequest, "INVALID_TMDB_ID", "Geçerli bir tmdbId gerekli", tmdbIdStr)
			return
		}

		movieKey := fmt.Sprintf("movie:%d:watchers", tmdbID)
		userIDs, err := config.RedisClient.SMembers(ctx, movieKey).Result()
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "WATCHERS_FETCH_FAILED", "İzleyenler alınamadı", err.Error())
			return
		}

		// Her izleyicinin detayını çek
		// OPTIMIZED: MongoDB $in operatörü ile tek sorguda kullanıcıları al
		var watchers []models.WatchStatus

		if len(userIDs) == 0 {
			c.JSON(http.StatusOK, gin.H{
				"tmdbId":       tmdbID,
				"watcherCount": 0,
				"watchers":     []models.WatchStatus{},
			})
			return
		}

		// Redis'ten tüm watch status'ları tek seferde al
		watchDataMap := make(map[string]string)
		for _, uid := range userIDs {
			watchKey := fmt.Sprintf("watching:%s", uid)
			data, err := config.RedisClient.Get(ctx, watchKey).Result()
			if err != nil {
				continue
			}
			watchDataMap[uid] = data
		}

		// MongoDB'den tüm kullanıcıları tek sorguda al
		userCollection := config.GetCollection(config.DB, "users")
		objIDs := make([]primitive.ObjectID, 0, len(userIDs))
		for _, uid := range userIDs {
			if objID, err := primitive.ObjectIDFromHex(uid); err == nil {
				objIDs = append(objIDs, objID)
			}
		}

		if len(objIDs) == 0 {
			c.JSON(http.StatusOK, gin.H{
				"tmdbId":       tmdbID,
				"watcherCount": 0,
				"watchers":     []models.WatchStatus{},
			})
			return
		}

		cursor, err := userCollection.Find(ctx, bson.M{"_id": bson.M{"$in": objIDs}})
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "USERS_FETCH_FAILED", "Kullanıcılar alınamadı", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var users []models.User
		if err := cursor.All(ctx, &users); err != nil {
			errorResponse(c, http.StatusInternalServerError, "USERS_READ_FAILED", "Kullanıcılar okunamadı", err.Error())
			return
		}

		// Kullanıcıları map'e dönüştür hızlı erişim için
		userMap := make(map[string]models.User)
		for _, user := range users {
			userMap[user.ID.Hex()] = user
		}

		// Her kullanıcı için gizlilik kontrolü yap
		for uid, data := range watchDataMap {
			target, exists := userMap[uid]
			if !exists {
				continue
			}

			isFriend := containsObjectID(target.Friends, viewerID)
			isMatched := areUsersMatched(ctx, viewerIDHex, uid)
			if !canViewerSeeWatching(viewerIDHex, viewerID, target.ID, isFriend, isMatched, userPrivacySettings(target)) {
				continue
			}

			var status models.WatchStatus
			if err := json.Unmarshal([]byte(data), &status); err != nil {
				continue
			}
			watchers = append(watchers, status)
		}

		c.JSON(http.StatusOK, gin.H{
			"tmdbId":       tmdbID,
			"watcherCount": len(watchers),
			"watchers":     watchers,
		})
	}
}

// RemoveWatchStatus — Kullanıcının izleme durumunu kaldırır
func RemoveWatchStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		clearPreviousStatus(ctx, userId)

		c.JSON(http.StatusOK, gin.H{
			"message": "İzleme durumu kaldırıldı!",
		})
	}
}

// GetMyStatus — Kullanıcının mevcut izleme durumunu döner
func GetMyStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		watchKey := fmt.Sprintf("watching:%s", userId)
		data, err := config.RedisClient.Get(ctx, watchKey).Result()
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"watching": false,
				"message":  "Şu an hiçbir şey izlemiyorsun",
			})
			return
		}

		var status models.WatchStatus
		if err := json.Unmarshal([]byte(data), &status); err != nil {
			errorResponse(c, http.StatusInternalServerError, "STATUS_READ_FAILED", "Durum okunamadı", err.Error())
			return
		}

		// Ne kadar süredir izliyor hesapla
		duration := time.Since(status.StartedAt)

		c.JSON(http.StatusOK, gin.H{
			"watching":    true,
			"status":      status,
			"watchingFor": fmt.Sprintf("%d dakika", int(duration.Minutes())),
		})
	}
}

type topActiveMovie struct {
	TmdbID       int    `json:"tmdbId"`
	MovieName    string `json:"movieName"`
	PosterPath   string `json:"posterPath"`
	WatcherCount int    `json:"watcherCount"`
}

// GetTopActiveMovies — Aktif izlenen filmleri izleyici sayısına göre sıralayıp döner
// Önceden Redis KEYS("watching:*") kullanılırken, şimdi watching:active_users set'i üzerinden çalışır.
func GetTopActiveMovies() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		limit := 5
		if limitStr := c.Query("limit"); limitStr != "" {
			if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= 20 {
				limit = parsed
			}
		}

		userIDs, err := config.RedisClient.SMembers(ctx, activeWatchingUsersKey).Result()
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "ACTIVE_MOVIES_FETCH_FAILED", "Aktif izlenen filmler alınamadı", err.Error())
			return
		}

		if len(userIDs) == 0 {
			c.JSON(http.StatusOK, gin.H{"movies": []topActiveMovie{}})
			return
		}

		// OPTIMIZED: Redis'ten toplu watch status'ları al
		watchDataMap := make(map[string]string)
		staleUsers := make([]string, 0)

		for _, uid := range userIDs {
			watchKey := fmt.Sprintf("watching:%s", uid)
			data, getErr := config.RedisClient.Get(ctx, watchKey).Result()
			if getErr != nil {
				staleUsers = append(staleUsers, uid)
				continue
			}
			watchDataMap[uid] = data
		}

		// MongoDB'den tüm kullanıcıları tek sorguda al (batch fetch)
		userCollection := config.GetCollection(config.DB, "users")

		// Önce tüm status'ları parse et ve userID'leri topla
		targetUserIDs := make([]primitive.ObjectID, 0, len(watchDataMap))
		statusByUserID := make(map[string]models.WatchStatus)

		for _, data := range watchDataMap {
			var status models.WatchStatus
			if err := json.Unmarshal([]byte(data), &status); err != nil {
				continue
			}

			posterPath := strings.TrimSpace(status.PosterPath)
			if status.TmdbID <= 0 || strings.TrimSpace(status.MovieName) == "" || posterPath == "" {
				continue
			}

			targetID, err := primitive.ObjectIDFromHex(status.UserID)
			if err != nil {
				continue
			}
			targetUserIDs = append(targetUserIDs, targetID)
			statusByUserID[status.UserID] = status
		}

		if len(targetUserIDs) == 0 {
			// Temizlik yap ve dön
			if len(staleUsers) > 0 {
				config.RedisClient.SRem(ctx, activeWatchingUsersKey, staleUsers)
			}
			c.JSON(http.StatusOK, gin.H{"movies": []topActiveMovie{}})
			return
		}

		// Batch query: $in operatörü ile tek sorguda kullanıcıları al
		cursor, err := userCollection.Find(ctx, bson.M{"_id": bson.M{"$in": targetUserIDs}})
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "USERS_FETCH_FAILED", "Kullanıcılar alınamadı", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var users []models.User
		if err := cursor.All(ctx, &users); err != nil {
			errorResponse(c, http.StatusInternalServerError, "USERS_READ_FAILED", "Kullanıcılar okunamadı", err.Error())
			return
		}

		// Kullanıcıları map'e dönüştür
		userMap := make(map[string]models.User)
		for _, user := range users {
			userMap[user.ID.Hex()] = user
		}

		// Filmleri aggregate et ve gizlilik kontrolü yap
		agg := make(map[int]*topActiveMovie)
		for userIDHex, status := range statusByUserID {
			user, exists := userMap[userIDHex]
			if !exists {
				continue
			}

			if userPrivacySettings(user).WatchingVisibility != "public" {
				continue
			}

			posterPath := strings.TrimSpace(status.PosterPath)
			if _, ok := agg[status.TmdbID]; !ok {
				agg[status.TmdbID] = &topActiveMovie{
					TmdbID:       status.TmdbID,
					MovieName:    status.MovieName,
					PosterPath:   posterPath,
					WatcherCount: 0,
				}
			}
			agg[status.TmdbID].WatcherCount++
		}

		if len(staleUsers) > 0 {
			config.RedisClient.SRem(ctx, activeWatchingUsersKey, staleUsers)
			log.Printf("[REDIS-KEYS-REFAC] GetTopActiveMovies cleaned stale active users count=%d", len(staleUsers))
		}
		log.Printf("[REDIS-KEYS-REFAC] GetTopActiveMovies activeUsers=%d aggregatedMovies=%d", len(userIDs), len(agg))

		movies := make([]topActiveMovie, 0, len(agg))
		for _, item := range agg {
			movies = append(movies, *item)
		}

		sort.Slice(movies, func(i, j int) bool {
			if movies[i].WatcherCount == movies[j].WatcherCount {
				return movies[i].TmdbID < movies[j].TmdbID
			}
			return movies[i].WatcherCount > movies[j].WatcherCount
		})

		if len(movies) > limit {
			movies = movies[:limit]
		}

		c.JSON(http.StatusOK, gin.H{"movies": movies})
	}
}

// clearPreviousStatus — Önceki izleme durumunu Redis'ten temizler
//   - watching:<userId> key'ini siler
//   - movie:<tmdbId>:watchers set'inden userId'yi kaldırır
//   - watching:active_users set'inden userId'yi kaldırır
func clearPreviousStatus(ctx context.Context, userId string) {
	watchKey := fmt.Sprintf("watching:%s", userId)
	data, err := config.RedisClient.Get(ctx, watchKey).Result()
	if err == nil {
		// Önceki filmin watchers set'inden çıkar
		var oldStatus models.WatchStatus
		if err := json.Unmarshal([]byte(data), &oldStatus); err == nil {
			movieKey := fmt.Sprintf("movie:%d:watchers", oldStatus.TmdbID)
			config.RedisClient.SRem(ctx, movieKey, userId)
		}
	}
	pipe := config.RedisClient.Pipeline()
	pipe.Del(ctx, watchKey)
	pipe.SRem(ctx, activeWatchingUsersKey, userId)
	_, _ = pipe.Exec(ctx)
}

// HeartbeatStatus — Kullanıcının izleme süresini uzatır (ping)
func HeartbeatStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		watchKey := fmt.Sprintf("watching:%s", userId)

		// Kullanıcı şu an izliyor mu kontrol et
		data, err := config.RedisClient.Get(ctx, watchKey).Result()
		if err != nil {
			errorResponse(c, http.StatusNotFound, "WATCH_STATUS_NOT_FOUND", "Aktif bir izleme durumu bulunamadı veya süresi doldu.", err.Error())
			return
		}

		// watchKey'in süresini 15 dakika daha uzat
		config.RedisClient.Expire(ctx, watchKey, 15*time.Minute)

		// Hangi filmi izliyorsa, o filmin watchers set'inin de süresini tazele
		var status models.WatchStatus
		if err := json.Unmarshal([]byte(data), &status); err == nil {
			movieKey := fmt.Sprintf("movie:%d:watchers", status.TmdbID)
			pipe := config.RedisClient.Pipeline()
			pipe.Expire(ctx, movieKey, 15*time.Minute)
			pipe.SAdd(ctx, activeWatchingUsersKey, userId)
			_, _ = pipe.Exec(ctx)
			log.Printf("[REDIS-KEYS-REFAC] HeartbeatStatus refreshed active user userId=%s tmdbId=%d", userId, status.TmdbID)
		}

		// Heartbeat geldiği sürece kullanıcıyı aktif set'te tut
		config.RedisClient.SAdd(ctx, "watching:active_users", userId)

		c.JSON(http.StatusOK, gin.H{"message": "İzleme durumu yenilendi!"})
	}
}
