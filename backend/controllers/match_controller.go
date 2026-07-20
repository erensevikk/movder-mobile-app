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
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		tmdbID, err := strconv.Atoi(c.Query("tmdbId"))
		if err != nil || tmdbID <= 0 {
			errorResponse(c, http.StatusBadRequest, "INVALID_TMDB_ID", "Geçerli bir tmdbId gerekli", nil)
			return
		}

		localOnly := c.Query("localOnly") == "1" || c.Query("localOnly") == "true"

		result, err := services.CheckForMatch(userID, tmdbID, localOnly)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "MATCH_CHECK_FAILED", "Eşleşme kontrolü başarısız", err.Error())
			return
		}

		if result == nil {
			c.JSON(http.StatusOK, gin.H{
				"matched": false,
				"message": "Henüz eşleşme bulunamadı. Beklemeye devam...",
			})
			return
		}

		var targetUserId, targetUserName string
		if result.User1ID == userID {
			targetUserId = result.User2ID
			targetUserName = result.User2Name
		} else {
			targetUserId = result.User1ID
			targetUserName = result.User1Name
		}

		c.JSON(http.StatusOK, gin.H{
			"matched": true,
			"message": "Eşleşme bulundu! 🎉",
			"match": gin.H{
				"roomId":         result.RoomID,
				"user1Id":        result.User1ID,
				"user1Name":      result.User1Name,
				"user2Id":        result.User2ID,
				"user2Name":      result.User2Name,
				"tmdbId":         result.TmdbID,
				"movieName":      result.MovieName,
				"targetUserId":   targetUserId,
				"targetUserName": targetUserName,
			},
		})
	}
}

// GetQueueCount — Bekleyen toplam kişi sayısını döner
func GetQueueCount() gin.HandlerFunc {
	return func(c *gin.Context) {
		count, err := services.GetTotalQueueCount()
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "QUEUE_READ_FAILED", "Kuyruk okunamadı", err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"queueCount": count})
	}
}

// CancelMatch — Eşleşme aramasını iptal eder ve kuyruktaki isteğini siler
func CancelMatch() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		var body struct {
			TmdbID int `json:"tmdbId"`
		}

		if err := c.ShouldBindJSON(&body); err != nil || body.TmdbID <= 0 {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "Geçerli bir tmdbId gerekli", nil)
			return
		}

		services.CancelMatchRequest(userID, body.TmdbID)

		c.JSON(http.StatusOK, gin.H{"message": "Arama iptal edildi, kuyruktan çıkıldı."})
	}
}

// AcceptMatch — Kullanıcının eşleşmeyi kabul ettiğini kaydeder.
// Her iki taraf kabul edince roomId'yi döner.
// Body: { "roomId": "...", "targetUserId": "..." }
func AcceptMatch() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		var body struct {
			RoomID       string `json:"roomId"`
			TargetUserID string `json:"targetUserId"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.RoomID == "" {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "roomId gerekli", nil)
			return
		}

		result, err := services.AcceptMatchAndGetRoom(userID, body.RoomID, body.TargetUserID)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "MATCH_ACCEPT_FAILED", "Eşleşme kabul edilemedi", err.Error())
			return
		}

		c.JSON(http.StatusOK, result)
	}
}

// RejectMatch — Kullanıcının eşleşmeyi reddettiğini kaydeder.
// Body: { "roomId": "...", "targetUserId": "..." }
func RejectMatch() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		var body struct {
			RoomID       string `json:"roomId"`
			TargetUserID string `json:"targetUserId"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.RoomID == "" {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "roomId gerekli", nil)
			return
		}

		err := services.RejectMatch(userID, body.RoomID, body.TargetUserID)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "MATCH_REJECT_FAILED", "Eşleşme reddedilemedi", err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Eşleşme reddedildi, aramaya devam..."})
	}
}

// GetAcceptStatus — Eşleşme kabul durumunu sorgular (polling için)
// Query: ?roomId=...
func GetAcceptStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}
		roomID := c.Query("roomId")
		if roomID == "" {
			errorResponse(c, http.StatusBadRequest, "MISSING_ROOM_ID", "roomId gerekli", nil)
			return
		}

		result, err := services.GetAcceptStatus(userID, roomID)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "MATCH_STATUS_FAILED", "Kabul durumu alınamadı", err.Error())
			return
		}

		c.JSON(http.StatusOK, result)
	}
}
