package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"movder-backend/config"
	"net/http"
	"net/url"
	"time"
)

const tmdbBaseURL = "https://api.themoviedb.org/3"

var tmdbHTTPClient = &http.Client{
	Timeout: 10 * time.Second,
}

// TMDB API yanıt yapıları
type TMDBMovie struct {
	ID            int     `json:"id"`
	Title         string  `json:"title"`
	Overview      string  `json:"overview"`
	PosterPath    string  `json:"poster_path"`
	BackdropPath  string  `json:"backdrop_path"`
	ReleaseDate   string  `json:"release_date"`
	VoteAverage   float64 `json:"vote_average"`
	VoteCount     int     `json:"vote_count"`
	GenreIDs      []int   `json:"genre_ids"`
	OriginalTitle string  `json:"original_title"`
	Popularity    float64 `json:"popularity"`
	WatcherCount  int     `json:"watcher_count"`
}

type TMDBSearchResponse struct {
	Page         int         `json:"page"`
	Results      []TMDBMovie `json:"results"`
	TotalPages   int         `json:"total_pages"`
	TotalResults int         `json:"total_results"`
}

type TMDBMovieDetail struct {
	ID                 int         `json:"id"`
	Title              string      `json:"title"`
	Overview           string      `json:"overview"`
	PosterPath         string      `json:"poster_path"`
	BackdropPath       string      `json:"backdrop_path"`
	ReleaseDate        string      `json:"release_date"`
	VoteAverage        float64     `json:"vote_average"`
	VoteCount          int         `json:"vote_count"`
	Runtime            int         `json:"runtime"`
	Genres             []TMDBGenre `json:"genres"`
	OriginalTitle      string      `json:"original_title"`
	Tagline            string      `json:"tagline"`
	Status             string      `json:"status"`
	WatcherCount       int         `json:"watcher_count"`
	IsOverviewFallback bool        `json:"is_overview_fallback"`
}

type TMDBGenre struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

// tmdbRequest TMDB API'ye Bearer token ile istek atar
func tmdbRequest(endpoint string) ([]byte, error) {
	token := config.GetEnv("TMDB_READ_TOKEN", "")
	if token == "" {
		return nil, fmt.Errorf("TMDB_READ_TOKEN ortam değişkeni bulunamadı")
	}

	req, err := http.NewRequest("GET", tmdbBaseURL+endpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("istek oluşturulamadı: %w", err)
	}

	// Bearer token ile yetkilendirme
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("accept", "application/json")

	resp, err := tmdbHTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("TMDB isteği başarısız: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("TMDB hata kodu: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("yanıt okunamadı: %w", err)
	}

	return body, nil
}

// --- Yardımcı Fonksiyonlar ---
func populateWatcherCounts(result *TMDBSearchResponse, ctx context.Context) *TMDBSearchResponse {
	for i, movie := range result.Results {
		movieKey := fmt.Sprintf("movie:%d:watchers", movie.ID)
		count, err := config.RedisClient.SCard(ctx, movieKey).Result()
		if err == nil {
			result.Results[i].WatcherCount = int(count)
		}
	}
	return result
}

func populateMovieWatcherCount(result *TMDBMovieDetail, ctx context.Context) *TMDBMovieDetail {
	movieKey := fmt.Sprintf("movie:%d:watchers", result.ID)
	count, err := config.RedisClient.SCard(ctx, movieKey).Result()
	if err == nil {
		result.WatcherCount = int(count)
	}
	return result
}

// SearchMovies film arar, 1 saat redis'te önbellekler
func SearchMovies(query string) (*TMDBSearchResponse, error) {
	escapedQuery := url.QueryEscape(query)
	cacheKey := fmt.Sprintf("tmdb:search:%s", escapedQuery)
	ctx := context.Background()

	// Önbelleği kontrol et
	cachedData, err := config.RedisClient.Get(ctx, cacheKey).Result()
	if err == nil && cachedData != "" {
		var result TMDBSearchResponse
		if err := json.Unmarshal([]byte(cachedData), &result); err == nil {
			return populateWatcherCounts(&result, ctx), nil
		}
	}

	endpoint := fmt.Sprintf("/search/movie?query=%s&language=tr-TR&include_adult=false&page=1", escapedQuery)

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	// Sadece sonuç varsa cache'le — boş sonuçları cache'leme
	if len(result.Results) > 0 {
		config.RedisClient.Set(ctx, cacheKey, body, time.Hour)
	}

	return populateWatcherCounts(&result, ctx), nil
}

// SearchMoviesWithYear film arar; yılı primary_release_year olarak TMDB'ye geçirir.
// Yılsız SearchMovies ile aynı cache mantığını paylaşır.
func SearchMoviesWithYear(query string, year int) (*TMDBSearchResponse, error) {
	escapedQuery := url.QueryEscape(query)
	cacheKey := fmt.Sprintf("tmdb:search:%s:y%d", escapedQuery, year)
	ctx := context.Background()

	// Önbelleği kontrol et
	cachedData, err := config.RedisClient.Get(ctx, cacheKey).Result()
	if err == nil && cachedData != "" {
		var result TMDBSearchResponse
		if err := json.Unmarshal([]byte(cachedData), &result); err == nil {
			return populateWatcherCounts(&result, ctx), nil
		}
	}

	endpoint := fmt.Sprintf(
		"/search/movie?query=%s&language=tr-TR&include_adult=false&page=1&primary_release_year=%d",
		escapedQuery, year,
	)

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	// Sadece sonuç varsa cache'le
	if len(result.Results) > 0 {
		config.RedisClient.Set(ctx, cacheKey, body, time.Hour)
	}

	return populateWatcherCounts(&result, ctx), nil
}

// GetMovieDetails TMDB ID ile tekil film detayını çeker, 12 saat redis'te önbellekler
func GetMovieDetails(tmdbID int) (*TMDBMovieDetail, error) {
	cacheKey := fmt.Sprintf("tmdb:movie:%d", tmdbID)
	ctx := context.Background()

	// Önbelleği kontrol et
	cachedData, err := config.RedisClient.Get(ctx, cacheKey).Result()
	if err == nil && cachedData != "" {
		var result TMDBMovieDetail
		if err := json.Unmarshal([]byte(cachedData), &result); err == nil {
			return populateMovieWatcherCount(&result, ctx), nil
		}
	}

	endpoint := fmt.Sprintf("/movie/%d?language=tr-TR", tmdbID)

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBMovieDetail
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	// İngilizce (en-US) fallback kontrolü
	// Eğer poster, backdrop veya özet eksikse İngilizcesini çek
	if result.Overview == "" || result.PosterPath == "" || result.BackdropPath == "" {
		endpointEN := fmt.Sprintf("/movie/%d?language=en-US", tmdbID)
		bodyEN, errEN := tmdbRequest(endpointEN)
		if errEN == nil {
			var resultEN TMDBMovieDetail
			if err := json.Unmarshal(bodyEN, &resultEN); err == nil {
				if result.Overview == "" {
					result.Overview = resultEN.Overview
					if result.Overview != "" {
						result.IsOverviewFallback = true
					}
				}
				if result.PosterPath == "" {
					result.PosterPath = resultEN.PosterPath
				}
				if result.BackdropPath == "" {
					result.BackdropPath = resultEN.BackdropPath
				}
				if result.Title == "" && resultEN.Title != "" {
					result.Title = resultEN.Title
				}
			}
		}
	}

	// Eksikleri tamamlanmış modeli cache'e yazmak için tekrar marshal ediyoruz
	finalBody, _ := json.Marshal(result)

	// Redis'e cache'le (12 saat)
	config.RedisClient.Set(ctx, cacheKey, finalBody, 12*time.Hour)

	return populateMovieWatcherCount(&result, ctx), nil
}

// GetTrending haftanın trend filmlerini getirir, 1 saat redis'te önbellekler
func GetTrending() (*TMDBSearchResponse, error) {
	cacheKey := "tmdb:trending"
	ctx := context.Background()

	cachedData, err := config.RedisClient.Get(ctx, cacheKey).Result()
	if err == nil && cachedData != "" {
		var result TMDBSearchResponse
		if err := json.Unmarshal([]byte(cachedData), &result); err == nil {
			return populateWatcherCounts(&result, ctx), nil
		}
	}

	endpoint := "/trending/movie/week?language=tr-TR"

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	// Cache (1 saat)
	config.RedisClient.Set(ctx, cacheKey, body, time.Hour)

	return populateWatcherCounts(&result, ctx), nil
}

// GetDiscoverMovies özel kategorilere göre filmleri çeker, 1 saat redis'te önbellekler
func GetDiscoverMovies(genres string, sortBy string) (*TMDBSearchResponse, error) {
	if sortBy == "" {
		sortBy = "popularity.desc" // Varsayılan popülerliğe göre
	}

	cacheKey := fmt.Sprintf("tmdb:discover:genres:%s:sort:%s", genres, sortBy)
	ctx := context.Background()

	cachedData, err := config.RedisClient.Get(ctx, cacheKey).Result()
	if err == nil && cachedData != "" {
		var result TMDBSearchResponse
		if err := json.Unmarshal([]byte(cachedData), &result); err == nil {
			return populateWatcherCounts(&result, ctx), nil
		}
	}

	endpoint := fmt.Sprintf("/discover/movie?language=tr-TR&page=1&sort_by=%s", sortBy)
	if genres != "" {
		endpoint += "&with_genres=" + genres
	}

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	config.RedisClient.Set(ctx, cacheKey, body, time.Hour)

	return populateWatcherCounts(&result, ctx), nil
}
