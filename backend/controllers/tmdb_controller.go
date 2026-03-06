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
			errorResponse(c, http.StatusBadRequest, "EMPTY_QUERY", "Arama sorgusu boş olamaz", nil)
			return
		}

		if len(query) > 100 {
			errorResponse(c, http.StatusBadRequest, "QUERY_TOO_LONG", "Arama sorgusu en fazla 100 karakter olabilir", nil)
			return
		}

		results, err := services.SearchMovies(query)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "MOVIE_SEARCH_FAILED", "Film araması başarısız", err.Error())
			return
		}

		// Sonuçları en fazla 5 ile sınırla — Flutter'a gereksiz veri gönderme
		if len(results.Results) > 5 {
			results.Results = results.Results[:5]
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
			errorResponse(c, http.StatusBadRequest, "INVALID_TMDB_ID", "Geçersiz film ID", nil)
			return
		}

		movie, err := services.GetMovieDetails(tmdbID)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "MOVIE_DETAILS_FAILED", "Film detayı alınamadı", err.Error())
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
			errorResponse(c, http.StatusInternalServerError, "TRENDING_FETCH_FAILED", "Trend filmler alınamadı", err.Error())
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
			errorResponse(c, http.StatusInternalServerError, "DISCOVER_FETCH_FAILED", "Filmler alınamadı", err.Error())
			return
		}

		c.JSON(http.StatusOK, results)
	}
}
