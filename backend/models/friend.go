package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// FriendRequest — Arkadaşlık isteği MongoDB belgesi
// from → to yönünde tek bir pending kaydı tutulur.
// Karşılıklı istek geldiğinde her iki kayıt silinir ve
// users koleksiyonundaki friends dizisine ekleme yapılır.
type FriendRequest struct {
	ID        primitive.ObjectID `json:"id,omitempty" bson:"_id,omitempty"`
	From      primitive.ObjectID `json:"from" bson:"from"`     // İstek gönderen
	To        primitive.ObjectID `json:"to" bson:"to"`         // İstek alıcı
	Status    string             `json:"status" bson:"status"` // "pending"
	CreatedAt time.Time          `json:"createdAt" bson:"createdAt"`
}
