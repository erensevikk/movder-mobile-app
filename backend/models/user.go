package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID           primitive.ObjectID   `json:"id,omitempty" bson:"_id,omitempty"`
	Username     string               `json:"username" bson:"username" binding:"required,min=3,max=30"`
	Email        string               `json:"email" bson:"email" binding:"required,email"`
	Password     string               `json:"password,omitempty" bson:"password" binding:"required,min=6"`
	City         string               `json:"city" bson:"city" binding:"required"`
	BirthDate    string               `json:"birthDate" bson:"birth_date" binding:"required"`
	Description  string               `json:"description,omitempty" bson:"description,omitempty"`
	AvatarURL    string               `json:"avatarUrl,omitempty" bson:"avatar_url,omitempty"`
	CreatedAt    time.Time            `json:"createdAt" bson:"createdAt"`
	Friends      []primitive.ObjectID `json:"friends,omitempty" bson:"friends,omitempty"`
	BlockedUsers []primitive.ObjectID `json:"blockedUsers,omitempty" bson:"blocked_users,omitempty"`
}

// LoginInput giriş için gerekli alanlar (kayıt modeli değil)
// Identifier alanı kullanıcı adı veya e-posta olabilir
type LoginInput struct {
	Identifier string `json:"identifier" binding:"required"`
	Password   string `json:"password" binding:"required"`
}
