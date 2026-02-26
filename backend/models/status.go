package models

import "time"

type WatchStatus struct {
	UserID     string    `json:"userId" bson:"userId"`
	Username   string    `json:"username" bson:"username"`
	TmdbID     int       `json:"tmdbId" bson:"tmdbId" binding:"required"`
	MovieName  string    `json:"movieName" bson:"movieName" binding:"required,max=200"`
	PosterPath string    `json:"posterPath" bson:"posterPath"`
	StartedAt  time.Time `json:"startedAt" bson:"startedAt"`
}
