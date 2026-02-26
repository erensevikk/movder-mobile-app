package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID        primitive.ObjectID `json:"id,omitempty" bson:"_id,omitempty"`
	Username  string             `json:"username" bson:"username" binding:"required,min=3,max=30"`
	Email     string             `json:"email" bson:"email" binding:"required,email"`
	Password  string             `json:"password,omitempty" bson:"password" binding:"required,min=6"`
	CreatedAt time.Time          `json:"createdAt" bson:"createdAt"`
}

// LoginInput giriş için gerekli alanlar (kayıt modeli değil)
type LoginInput struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}
