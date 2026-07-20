package routes

import (
	"movder-backend/controllers"
	"movder-backend/middleware"

	"github.com/gin-gonic/gin"
)

func MatchRoutes(r *gin.Engine) {
	match := r.Group("/api/match")
	match.Use(middleware.AuthMiddleware())
	{
		match.GET("/check", controllers.CheckMatch())              // Eşleşme kontrolü
		match.POST("/cancel", controllers.CancelMatch())           // Eşleşme iptali
		match.GET("/queue-count", controllers.GetQueueCount())     // Kuyruk sayısı
		match.POST("/accept", controllers.AcceptMatch())           // Eşleşmeyi kabul et
		match.POST("/reject", controllers.RejectMatch())           // Eşleşmeyi reddet
		match.GET("/accept-status", controllers.GetAcceptStatus()) // Kabul durumunu sorgula
		match.GET("/ws", controllers.HandleMatchWebSocket())       // WebSocket Eşleşme (YENİ)
	}
}
