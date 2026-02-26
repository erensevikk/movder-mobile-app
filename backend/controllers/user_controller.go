package controllers

import (
	"context"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

func RegisterUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user models.User

		// Gelen JSON'u modele bağla
		if err := c.BindJSON(&user); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri formatı!"})
			return
		}

		user.ID = primitive.NewObjectID()
		userCollection := config.GetCollection(config.DB, "users")

		_, err := userCollection.InsertOne(ctx, user)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcı oluşturulamadı!"})
			return
		}

		c.JSON(http.StatusCreated, gin.H{
			"message": "Kullanıcı başarıyla oluşturuldu!",
			"userId":  user.ID,
		})
	}
}
