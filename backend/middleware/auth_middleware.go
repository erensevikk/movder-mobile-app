package middleware

import (
	"movder-backend/config"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// AuthMiddleware — JWT token doğrulama middleware'i
// Authorization header'ından "Bearer <token>" alır, doğrular ve userId'yi context'e ekler
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")

		// 1. Header var mı kontrol et
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Yetkilendirme başlığı gerekli!"})
			c.Abort()
			return
		}

		// 2. "Bearer " prefix'ini kontrol et ve kaldır
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz token formatı! (Bearer <token>)"})
			c.Abort()
			return
		}
		tokenString := parts[1]

		// 3. Token'ı doğrula
		jwtSecret := config.GetEnv("JWT_SECRET", "default_secret")
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			// HMAC yöntemi doğrulaması (algorithm confusion saldırısına karşı)
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(jwtSecret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz veya süresi dolmuş token!"})
			c.Abort()
			return
		}

		// 4. Claims'ten bilgileri çıkar ve context'e ekle
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token bilgileri okunamadı!"})
			c.Abort()
			return
		}

		c.Set("userId", claims["userId"])
		c.Set("email", claims["email"])
		c.Set("username", claims["username"])

		c.Next()
	}
}
