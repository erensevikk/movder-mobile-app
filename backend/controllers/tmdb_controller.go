package controllers

import (
	"movder-backend/services"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

// SearchMovies — Film arama endpoint handler'ı
// Input doğrulama: boş sorgu engellenir, max 100 karakter, URL escape yapılır
func SearchMovies() gin.HandlerFunc {
	return func(c *gin.Context) {
		query := strings.TrimSpace(c.Query("q"))

		if len(query) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Arama sorgusu boş olamaz"})
			return
		}

		if len(query) > 100 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Arama sorgusu en fazla 100 karakter olabilir"})
			return
		}

		results, err := services.SearchMovies(query)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Film araması başarısız: " + err.Error()})
			return
		}

		c.JSON(http.StatusOK, results)
	}
}

// GetMovieDetails — Tek film detayı endpoint handler'ı
func GetMovieDetails() gin.HandlerFunc {
	return func(c *gin.Context) {
		idStr := c.Param("id")
		tmdbID, err := strconv.Atoi(idStr)
		if err != nil || tmdbID <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz film ID"})
			return
		}

		movie, err := services.GetMovieDetails(tmdbID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Film detayı alınamadı: " + err.Error()})
			return
		}

		c.JSON(http.StatusOK, movie)
	}
}

// GetTrending — Haftalık trend filmler endpoint handler'ı
func GetTrending() gin.HandlerFunc {
	return func(c *gin.Context) {
		results, err := services.GetTrending()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Trend filmler alınamadı: " + err.Error()})
			return
		}

		c.JSON(http.StatusOK, results)
	}
}

// GetDiscoverMovies — Belirli türlere (genre) göre filmleri filtreleyen endpoint handler'ı
func GetDiscoverMovies() gin.HandlerFunc {
	return func(c *gin.Context) {
		genres := c.Query("genres")
		sortBy := c.Query("sort_by")

		results, err := services.GetDiscoverMovies(genres, sortBy)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Filmler alınamadı: " + err.Error()})
			return
		}

		c.JSON(http.StatusOK, results)
	}
}
