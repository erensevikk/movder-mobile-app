package controllers

import (
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
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDHex, ok := mustUserID(c)
		if !ok {
			return
		}

		notifCol := config.GetCollection(config.DB, "notifications")
		findOptions := options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}})

		cursor, err := notifCol.Find(ctx, bson.M{"userId": userIDHex}, findOptions)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "NOTIFICATIONS_FETCH_FAILED", "Bildirimler alınamadı", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var notifications []Notification
		if err = cursor.All(ctx, &notifications); err != nil {
			errorResponse(c, http.StatusInternalServerError, "NOTIFICATIONS_DECODE_FAILED", "Bildirim verileri çözümlenemedi", err.Error())
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
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDHex, ok := mustUserID(c)
		if !ok {
			return
		}

		notifID := c.Param("id")
		objID, ok := parseObjectIDOrBadRequest(c, notifID, "bildirim kimliği")
		if !ok {
			return
		}

		notifCol := config.GetCollection(config.DB, "notifications")
		_, err := notifCol.UpdateOne(
			ctx,
			bson.M{"_id": objID, "userId": userIDHex},
			bson.M{"$set": bson.M{"isRead": true}},
		)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "NOTIFICATION_UPDATE_FAILED", "Bildirim güncellenemedi", err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Bildirim okundu olarak işaretlendi"})
	}
}

func MarkAllAsRead() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDHex, ok := mustUserID(c)
		if !ok {
			return
		}

		notifCol := config.GetCollection(config.DB, "notifications")
		_, err := notifCol.UpdateMany(
			ctx,
			bson.M{"userId": userIDHex, "isRead": false},
			bson.M{"$set": bson.M{"isRead": true}},
		)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "NOTIFICATIONS_UPDATE_FAILED", "Bildirimler güncellenemedi", err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Tüm bildirimler okundu olarak işaretlendi"})
	}
}

func DeleteNotification() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDHex, ok := mustUserID(c)
		if !ok {
			return
		}

		notifID := c.Param("id")
		objID, ok := parseObjectIDOrBadRequest(c, notifID, "bildirim kimliği")
		if !ok {
			return
		}

		notifCol := config.GetCollection(config.DB, "notifications")
		result, err := notifCol.DeleteOne(ctx, bson.M{
			"_id":    objID,
			"userId": userIDHex,
		})
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "NOTIFICATION_DELETE_FAILED", "Bildirim silinemedi", err.Error())
			return
		}
		if result.DeletedCount == 0 {
			errorResponse(c, http.StatusNotFound, "NOTIFICATION_NOT_FOUND", "Bildirim bulunamadı", nil)
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Bildirim silindi"})
	}
}
