package controllers

import (
	"context"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"golang.org/x/crypto/bcrypt"
)

// RegisterUser — Kullanıcı kaydı
// Input doğrulama: Gin binding tag'leri (required, email, min, max)
// Güvenlik: bcrypt ile şifre hash'leme, email tekrarı kontrolü
func RegisterUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user models.User

		// 1. Input doğrulama (binding tag'leri çalışır)
		if err := c.ShouldBindJSON(&user); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		// 2. Email tekrarı kontrolü
		var existingUser models.User
		err := userCollection.FindOne(ctx, bson.M{"email": user.Email}).Decode(&existingUser)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Bu e-posta adresi zaten kayıtlı!"})
			return
		}

		// 3. Şifreyi bcrypt ile hash'le
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Şifre işlenemedi!"})
			return
		}
		user.Password = string(hashedPassword)

		// 4. ID ve zaman damgası ata
		user.ID = primitive.NewObjectID()
		user.CreatedAt = time.Now()

		// 5. Veritabanına yaz
		_, err = userCollection.InsertOne(ctx, user)
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

// LoginUser — Kullanıcı girişi
// Email ile bulur, bcrypt ile şifreyi doğrular, JWT token üretir
func LoginUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var input models.LoginInput

		// 1. Input doğrulama
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		// 2. Email ile kullanıcıyı bul
		var user models.User
		err := userCollection.FindOne(ctx, bson.M{"email": input.Email}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "E-posta veya şifre hatalı!"})
			return
		}

		// 3. Şifreyi doğrula
		err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(input.Password))
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "E-posta veya şifre hatalı!"})
			return
		}

		// 4. JWT token üret
		jwtSecret := config.GetEnv("JWT_SECRET", "default_secret")
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"userId":   user.ID.Hex(),
			"email":    user.Email,
			"username": user.Username,
			"exp":      time.Now().Add(24 * time.Hour).Unix(),
		})

		tokenString, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Token üretilemedi!"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":  "Giriş başarılı!",
			"token":    tokenString,
			"userId":   user.ID,
			"username": user.Username,
		})
	}
}

// GetProfile — JWT ile korunan profil endpoint'i
func GetProfile() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		email := c.GetString("email")
		username := c.GetString("username")

		c.JSON(http.StatusOK, gin.H{
			"userId":   userId,
			"email":    email,
			"username": username,
		})
	}
}
