package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"strconv"
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
		pipe.Set(ctx, watchKey, statusJSON, 6*time.Hour) // 6 saat TTL
		pipe.SAdd(ctx, movieKey, userId)                 // İzleyenler set'ine ekle
		pipe.Expire(ctx, movieKey, 6*time.Hour)          // Set'e de TTL koy
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
