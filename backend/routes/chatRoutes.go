package routes

import (
	"movder-backend/controllers"
	"movder-backend/middleware"

	"github.com/gin-gonic/gin"
)

func ChatRoutes(r *gin.Engine) {
	// WebSocket bağlantısı — JWT token query parametresi ile doğrulanır
	r.GET("/ws/chat/:roomId", controllers.HandleWebSocket())

	// Korumalı REST rotaları (JWT zorunlu)
	protected := r.Group("/api/chat")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.GET("/rooms", controllers.GetChatRooms())
		protected.GET("/rooms/:roomId/messages", controllers.GetChatMessages())
		protected.DELETE("/rooms/:roomId", controllers.HideChatRoom())
	}
}
