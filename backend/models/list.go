package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// List â€” Kullanıcının oluşturduğu film koleksiyonları (Kategoriler)
type List struct {
	ID          primitive.ObjectID `json:"id,omitempty" bson:"_id,omitempty"`
	UserID      string             `json:"userId" bson:"userId"`                             // Listeyi oluşturan kişi
	Name        string             `json:"name" bson:"name" binding:"required,min=2,max=50"` // Örn: "Ağlatanlar", "Aksiyon Zirvesi"
	Description string             `json:"description" bson:"description"`                   // Liste ile ilgili not/açıklama
	IsPublic    bool               `json:"isPublic" bson:"isPublic"`                         // Diğer kullanıcılar görebilir mi? (Letterboxd stili)
	CreatedAt   time.Time          `json:"createdAt" bson:"createdAt"`
	UpdatedAt   time.Time          `json:"updatedAt" bson:"updatedAt"`
}

// ListItem â€” Bir listenin içindeki her bir film
type ListItem struct {
	ID        primitive.ObjectID `json:"id,omitempty" bson:"_id,omitempty"`
	ListID    primitive.ObjectID `json:"listId" bson:"listId" binding:"required"` // Hangi listeye ait
	Position  int                `json:"position" bson:"position"`                // Letterboxd sıra bilgisi
	TmdbID    int                `json:"tmdbId" bson:"tmdbId" binding:"required"` // TMDB film id
	MovieName string             `json:"movieName" bson:"movieName"`              // Film Adı
	PosterURL string             `json:"posterUrl" bson:"posterUrl"`              // Afiş linki
	AddedAt   time.Time          `json:"addedAt" bson:"addedAt"`                  // Listeye eklenme tarihi
}

// CreateListInput â€” Yeni bir liste oluştururken beklenen istek gövdesi
type CreateListInput struct {
	Name        string `json:"name" binding:"required,min=2,max=50"`
	Description string `json:"description"`
	IsPublic    bool   `json:"isPublic"`
}

// AddToListInput â€” Bir listeye film eklerken beklenen istek gövdesi
type AddToListInput struct {
	ListID    string `json:"listId" binding:"required"`
	Position  int    `json:"position"`
	TmdbID    int    `json:"tmdbId" binding:"required"`
	MovieName string `json:"movieName" binding:"required"`
	PosterURL string `json:"posterUrl"`
}
