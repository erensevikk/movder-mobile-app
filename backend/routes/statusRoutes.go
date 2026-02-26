package routes

import (
	"movder-backend/controllers"
	"movder-backend/middleware"

	"github.com/gin-gonic/gin"
)

func StatusRoutes(r *gin.Engine) {
	// Tüm status endpoint'leri JWT koruması altında
	status := r.Group("/api/status")
	status.Use(middleware.AuthMiddleware())
	{
		status.POST("", controllers.SetWatchStatus())          // İzleme durumu belirle
		status.GET("/me", controllers.GetMyStatus())           // Kendi izleme durumumu gör
		status.DELETE("", controllers.RemoveWatchStatus())     // İzlemeyi bitir
		status.GET("/active", controllers.GetActiveWatchers()) // Bir filmi izleyenleri listele
	}
}
