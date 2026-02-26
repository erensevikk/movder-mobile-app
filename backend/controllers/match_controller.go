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
