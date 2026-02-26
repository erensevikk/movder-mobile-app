package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"movder-backend/config"
	"net/http"
	"net/url"
)

const tmdbBaseURL = "https://api.themoviedb.org/3"

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
	ID            int         `json:"id"`
	Title         string      `json:"title"`
	Overview      string      `json:"overview"`
	PosterPath    string      `json:"poster_path"`
	BackdropPath  string      `json:"backdrop_path"`
	ReleaseDate   string      `json:"release_date"`
	VoteAverage   float64     `json:"vote_average"`
	VoteCount     int         `json:"vote_count"`
	Runtime       int         `json:"runtime"`
	Genres        []TMDBGenre `json:"genres"`
	OriginalTitle string      `json:"original_title"`
	Tagline       string      `json:"tagline"`
	Status        string      `json:"status"`
	WatcherCount  int         `json:"watcher_count"`
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

	// Bearer token ile yetkilendirme (v4 yöntemi — önerilen)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("accept", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
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

// SearchMovies film arar — query parametresi url.QueryEscape ile güvenli hale getirilir
func SearchMovies(query string) (*TMDBSearchResponse, error) {
	escapedQuery := url.QueryEscape(query)
	endpoint := fmt.Sprintf("/search/movie?query=%s&language=tr-TR&page=1", escapedQuery)

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	// Redis'ten anlık izleyici sayılarını çek
	ctx := context.Background()
	for i, movie := range result.Results {
		movieKey := fmt.Sprintf("movie:%d:watchers", movie.ID)
		count, err := config.RedisClient.SCard(ctx, movieKey).Result()
		if err == nil {
			result.Results[i].WatcherCount = int(count)
		}
	}

	return &result, nil
}

// GetMovieDetails TMDB ID ile tekil film detayını çeker
func GetMovieDetails(tmdbID int) (*TMDBMovieDetail, error) {
	endpoint := fmt.Sprintf("/movie/%d?language=tr-TR", tmdbID)

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBMovieDetail
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	// Redis'ten anlık izleyici sayısını çek
	ctx := context.Background()
	movieKey := fmt.Sprintf("movie:%d:watchers", result.ID)
	count, err := config.RedisClient.SCard(ctx, movieKey).Result()
	if err == nil {
		result.WatcherCount = int(count)
	}

	return &result, nil
}

// GetTrending haftanın trend filmlerini getirir
func GetTrending() (*TMDBSearchResponse, error) {
	endpoint := "/trending/movie/week?language=tr-TR"

	body, err := tmdbRequest(endpoint)
	if err != nil {
		return nil, err
	}

	var result TMDBSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("JSON parse hatası: %w", err)
	}

	// Redis'ten anlık izleyici sayılarını çek
	ctx := context.Background()
	for i, movie := range result.Results {
		movieKey := fmt.Sprintf("movie:%d:watchers", movie.ID)
		count, err := config.RedisClient.SCard(ctx, movieKey).Result()
		if err == nil {
			result.Results[i].WatcherCount = int(count)
		}
	}

	return &result, nil
}

// GetDiscoverMovies özel kategorilere göre (tür, sıralama) filmleri çeker (örn: flört konsepti listeleri için)
func GetDiscoverMovies(genres string, sortBy string) (*TMDBSearchResponse, error) {
	if sortBy == "" {
		sortBy = "popularity.desc" // Varsayılan popülerliğe göre
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

	// Redis'ten anlık izleyici sayılarını çek
	ctx := context.Background()
	for i, movie := range result.Results {
		movieKey := fmt.Sprintf("movie:%d:watchers", movie.ID)
		count, err := config.RedisClient.SCard(ctx, movieKey).Result()
		if err == nil {
			result.Results[i].WatcherCount = int(count)
		}
	}

	return &result, nil
}
