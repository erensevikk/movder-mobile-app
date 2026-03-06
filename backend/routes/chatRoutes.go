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
		// OPTIMIZED: Aggregation kullanan versiyon (N+1 query çözüldü)
		protected.GET("/rooms", controllers.GetChatRoomsOptimized())

		// OPTIMIZED: Pagination destekli versiyon (limit + cursor)
		protected.GET("/rooms/:roomId/messages", controllers.GetChatMessagesPaginated())

		protected.DELETE("/rooms/:roomId", controllers.HideChatRoom())
	}
}
