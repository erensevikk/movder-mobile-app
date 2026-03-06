package controllers

import (
	"context"
	"movder-backend/config"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Notification struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	UserID    string             `bson:"userId" json:"userId"`
	Type      string             `bson:"type" json:"type"`
	SenderID  string             `bson:"senderId,omitempty" json:"senderId,omitempty"`
	Title     string             `bson:"title" json:"title"`
	Message   string             `bson:"message" json:"message"`
	Avatar    string             `bson:"avatar,omitempty" json:"avatar,omitempty"`
	IsRead    bool               `bson:"isRead" json:"isRead"`
	CreatedAt time.Time          `bson:"createdAt" json:"createdAt"`
}

func GetNotifications() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		if userIDHex == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Yetkisiz erisim"})
			return
		}

		notifCol := config.GetCollection(config.DB, "notifications")
		findOptions := options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}})

		cursor, err := notifCol.Find(ctx, bson.M{"userId": userIDHex}, findOptions)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Bildirimler alinamadi"})
			return
		}
		defer cursor.Close(ctx)

		var notifications []Notification
		if err = cursor.All(ctx, &notifications); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Veri cozumleme hatasi"})
			return
		}

		if notifications == nil {
			notifications = []Notification{}
		}

		c.JSON(http.StatusOK, gin.H{"notifications": notifications})
	}
}

func MarkAsRead() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		notifID := c.Param("id")

		objID, err := primitive.ObjectIDFromHex(notifID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Gecersiz bildirim ID'si"})
			return
		}

		notifCol := config.GetCollection(config.DB, "notifications")
		_, err = notifCol.UpdateOne(
			ctx,
			bson.M{"_id": objID, "userId": userIDHex},
			bson.M{"$set": bson.M{"isRead": true}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Bildirim guncellenemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Bildirim okundu olarak isaretlendi"})
	}
}

func MarkAllAsRead() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		notifCol := config.GetCollection(config.DB, "notifications")

		_, err := notifCol.UpdateMany(
			ctx,
			bson.M{"userId": userIDHex, "isRead": false},
			bson.M{"$set": bson.M{"isRead": true}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Bildirimler guncellenemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Tum bildirimler okundu olarak isaretlendi"})
	}
}

func DeleteNotification() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		notifID := c.Param("id")

		objID, err := primitive.ObjectIDFromHex(notifID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Gecersiz bildirim ID'si"})
			return
		}

		notifCol := config.GetCollection(config.DB, "notifications")
		result, err := notifCol.DeleteOne(ctx, bson.M{
			"_id":    objID,
			"userId": userIDHex,
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Bildirim silinemedi"})
			return
		}
		if result.DeletedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Bildirim bulunamadi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Bildirim silindi"})
	}
}
