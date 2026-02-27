package routes

import (
	"movder-backend/controllers"
	"movder-backend/middleware"

	"github.com/gin-gonic/gin"
)

func FriendRoutes(r *gin.Engine) {
	friends := r.Group("/api/friends")
	friends.Use(middleware.AuthMiddleware())
	{
		friends.POST("/request", controllers.SendFriendRequest())       // İstek gönder (karşılıklı onay mantığıyla)
		friends.GET("", controllers.GetFriends())                       // Arkadaş listesi
		friends.DELETE("/:friendId", controllers.RemoveFriend())        // Arkadaşlıktan çıkar
		friends.GET("/status/:targetId", controllers.GetFriendStatus()) // İki kullanıcı arası durum
	}
}
