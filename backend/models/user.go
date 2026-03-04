package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type WatchHistoryItem struct {
	TmdbID     int       `json:"tmdbId" bson:"tmdb_id"`
	MovieName  string    `json:"movieName" bson:"movie_name"`
	PosterPath string    `json:"posterPath" bson:"poster_path"`
	WatchedAt  time.Time `json:"watchedAt" bson:"watched_at"`
}

type User struct {
	ID                 primitive.ObjectID   `json:"id,omitempty" bson:"_id,omitempty"`
	Username           string               `json:"username" bson:"username" binding:"required,min=3,max=30"`
	Email              string               `json:"email" bson:"email" binding:"required,email"`
	Password           string               `json:"password,omitempty" bson:"password" binding:"required,min=6"`
	City               string               `json:"city" bson:"city" binding:"required"`
	BirthDate          string               `json:"birthDate" bson:"birth_date" binding:"required"`
	Description        string               `json:"description,omitempty" bson:"description,omitempty"`
	AvatarURL          string               `json:"avatarUrl,omitempty" bson:"avatar_url,omitempty"`
	CoverURL           string               `json:"coverUrl,omitempty" bson:"cover_url,omitempty"`
	LetterboxdImported bool                 `json:"letterboxdImported" bson:"letterboxd_imported"`
	CreatedAt          time.Time            `json:"createdAt" bson:"createdAt"`
	Friends            []primitive.ObjectID `json:"friends,omitempty" bson:"friends,omitempty"`
	BlockedUsers       []primitive.ObjectID `json:"blockedUsers,omitempty" bson:"blocked_users,omitempty"`
	UnmatchedUsers     []primitive.ObjectID `json:"unmatchedUsers,omitempty" bson:"unmatched_users,omitempty"`
	WatchHistory       []WatchHistoryItem   `json:"watchHistory,omitempty" bson:"watch_history,omitempty"`
}

// LoginInput giriş için gerekli alanlar (kayıt modeli değil)
// Identifier alanı kullanıcı adı veya e-posta olabilir
type LoginInput struct {
	Identifier string `json:"identifier" binding:"required"`
	Password   string `json:"password" binding:"required"`
}
