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
		match.GET("/check", controllers.CheckMatch()) // Eşleşme kontrolü
	}
}
