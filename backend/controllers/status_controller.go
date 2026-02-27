package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// SetWatchStatus — Kullanıcının izleme durumunu belirler
// userId JWT token'dan alınır (manipülasyon engeli)
// Redis'te iki key oluşturulur:
//   - watching:<userId> → Hash (film bilgileri, TTL: 6 saat)
//   - movie:<tmdbId>:watchers → Set (bu filmi izleyenlerin listesi)
func SetWatchStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := context.Background()

		// userId ve username JWT middleware'den geliyor
		userId := c.GetString("userId")
		username := c.GetString("username")

		var input models.WatchStatus
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
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
		_, err := pipe.Exec(ctx)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "İzleme durumu kaydedilemedi"})
			return
		}

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
		ctx := context.Background()

		tmdbIdStr := c.Query("tmdbId")
		tmdbID, err := strconv.Atoi(tmdbIdStr)
		if err != nil || tmdbID <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçerli bir tmdbId gerekli"})
			return
		}

		movieKey := fmt.Sprintf("movie:%d:watchers", tmdbID)
		userIDs, err := config.RedisClient.SMembers(ctx, movieKey).Result()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "İzleyenler alınamadı"})
			return
		}

		// Her izleyicinin detayını çek
		var watchers []models.WatchStatus
		for _, uid := range userIDs {
			watchKey := fmt.Sprintf("watching:%s", uid)
			data, err := config.RedisClient.Get(ctx, watchKey).Result()
			if err != nil {
				continue // TTL dolmuş veya kullanıcı çıkmış
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
		ctx := context.Background()
		userId := c.GetString("userId")

		clearPreviousStatus(ctx, userId)

		c.JSON(http.StatusOK, gin.H{
			"message": "İzleme durumu kaldırıldı!",
		})
	}
}

// GetMyStatus — Kullanıcının mevcut izleme durumunu döner
func GetMyStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := context.Background()
		userId := c.GetString("userId")

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
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Durum okunamadı"})
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
func GetTopActiveMovies() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := context.Background()

		limit := 5
		if limitStr := c.Query("limit"); limitStr != "" {
			if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= 20 {
				limit = parsed
			}
		}

		keys, err := config.RedisClient.Keys(ctx, "watching:*").Result()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Aktif izlenen filmler alınamadı"})
			return
		}

		if len(keys) == 0 {
			c.JSON(http.StatusOK, gin.H{"movies": []topActiveMovie{}})
			return
		}

		agg := make(map[int]*topActiveMovie)

		for _, key := range keys {
			data, err := config.RedisClient.Get(ctx, key).Result()
			if err != nil {
				continue
			}

			var status models.WatchStatus
			if err := json.Unmarshal([]byte(data), &status); err != nil {
				continue
			}

			posterPath := strings.TrimSpace(status.PosterPath)
			if status.TmdbID <= 0 || strings.TrimSpace(status.MovieName) == "" || posterPath == "" {
				continue
			}

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
	config.RedisClient.Del(ctx, watchKey)
}

// HeartbeatStatus — Kullanıcının izleme süresini uzatır (ping)
func HeartbeatStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := context.Background()
		userId := c.GetString("userId")

		watchKey := fmt.Sprintf("watching:%s", userId)

		// Kullanıcı şu an izliyor mu kontrol et
		data, err := config.RedisClient.Get(ctx, watchKey).Result()
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Aktif bir izleme durumu bulunamadı veya süresi doldu."})
			return
		}

		// watchKey'in süresini 15 dakika daha uzat
		config.RedisClient.Expire(ctx, watchKey, 15*time.Minute)

		// Hangi filmi izliyorsa, o filmin watchers set'inin de süresini tazele
		var status models.WatchStatus
		if err := json.Unmarshal([]byte(data), &status); err == nil {
			movieKey := fmt.Sprintf("movie:%d:watchers", status.TmdbID)
			config.RedisClient.Expire(ctx, movieKey, 15*time.Minute)
		}

		c.JSON(http.StatusOK, gin.H{"message": "İzleme durumu yenilendi!"})
	}
}
