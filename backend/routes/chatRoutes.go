package routes

import (
	"movder-backend/controllers"

	"github.com/gin-gonic/gin"
)

func ChatRoutes(r *gin.Engine) {
	// WebSocket bağlantısı — JWT token query parametresi ile doğrulanır
	r.GET("/ws/chat/:roomId", controllers.HandleWebSocket())
}
