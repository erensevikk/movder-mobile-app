package routes

import (
	"movder-backend/controllers"

	"github.com/gin-gonic/gin"
)

func UserRoutes(r *gin.Engine) {
	// Artık /register adresine POST isteği atabiliriz
	r.POST("/register", controllers.RegisterUser())
}
