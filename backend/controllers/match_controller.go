package controllers

import (
	"movder-backend/services"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// CheckMatch — Kullanıcının mevcut izlediği film için eşleşme olup olmadığını kontrol eder
func CheckMatch() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")

		tmdbIdStr := c.Query("tmdbId")
		tmdbID, err := strconv.Atoi(tmdbIdStr)
		if err != nil || tmdbID <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçerli bir tmdbId gerekli"})
			return
		}

		result, err := services.CheckForMatch(userId, tmdbID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Eşleşme kontrolü başarısız"})
			return
		}

		if result == nil {
			c.JSON(http.StatusOK, gin.H{
				"matched": false,
				"message": "Henüz eşleşme bulunamadı. Beklemeye devam...",
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"matched": true,
			"message": "Eşleşme bulundu! 🎉",
			"match":   result,
		})
	}
}

// GetQueueCount — Bekleyen toplam kişi sayısını döner
func GetQueueCount() gin.HandlerFunc {
	return func(c *gin.Context) {
		count, err := services.GetTotalQueueCount()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kuyruk okunamadı"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"queueCount": count})
	}
}

// CancelMatch — Eşleşme aramasını iptal eder ve kuyruktaki isteğini siler
func CancelMatch() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")

		var body struct {
			TmdbID int `json:"tmdbId"`
		}

		if err := c.ShouldBindJSON(&body); err != nil || body.TmdbID <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçerli bir tmdbId gerekli"})
			return
		}

		services.CancelMatchRequest(userId, body.TmdbID)

		c.JSON(http.StatusOK, gin.H{"message": "Arama iptal edildi, kuyruktan çıkıldı."})
	}
}

// AcceptMatch — Kullanıcının eşleşmeyi kabul ettiğini kaydeder.
// Her iki taraf kabul edince roomId'yi döner.
// Body: { "roomId": "...", "targetUserId": "..." }
func AcceptMatch() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")

		var body struct {
			RoomID       string `json:"roomId"`
			TargetUserID string `json:"targetUserId"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.RoomID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "roomId gerekli"})
			return
		}

		result, err := services.AcceptMatchAndGetRoom(userId, body.RoomID, body.TargetUserID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, result)
	}
}

// RejectMatch — Kullanıcının eşleşmeyi reddettiğini kaydeder.
// Body: { "roomId": "...", "targetUserId": "..." }
func RejectMatch() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")

		var body struct {
			RoomID       string `json:"roomId"`
			TargetUserID string `json:"targetUserId"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.RoomID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "roomId gerekli"})
			return
		}

		err := services.RejectMatch(userId, body.RoomID, body.TargetUserID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Eşleşme reddedildi, aramaya devam..."})
	}
}

// GetAcceptStatus — Eşleşme kabul durumunu sorgular (polling için)
// Query: ?roomId=...
func GetAcceptStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		roomID := c.Query("roomId")
		if roomID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "roomId gerekli"})
			return
		}

		result, err := services.GetAcceptStatus(userId, roomID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, result)
	}
}
