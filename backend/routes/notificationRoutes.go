package routes

import (
	"movder-backend/controllers"
	"movder-backend/middleware"

	"github.com/gin-gonic/gin"
)

func NotificationRoutes(r *gin.Engine) {
	notification := r.Group("/api/notifications")
	notification.Use(middleware.AuthMiddleware())
	{
		notification.GET("", controllers.GetNotifications())
		notification.PUT("/read-all", controllers.MarkAllAsRead())
		notification.PUT("/:id/read", controllers.MarkAsRead())
		notification.DELETE("/:id", controllers.DeleteNotification())
	}
}
