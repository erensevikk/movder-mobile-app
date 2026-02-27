package routes

import (
	"movder-backend/controllers"
	"movder-backend/middleware"

	"github.com/gin-gonic/gin"
)

func UserRoutes(r *gin.Engine) {
	// Açık rotalar — JWT gerektirmez
	r.POST("/register", controllers.RegisterUser())
	r.POST("/login", controllers.LoginUser())

	// Korunan rotalar — JWT zorunlu
	protected := r.Group("/api")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.GET("/profile", controllers.GetProfile())
		protected.POST("/profile", controllers.UpdateProfile())
		protected.GET("/users/search", controllers.SearchUsers())
		protected.GET("/users/:targetId", controllers.GetUserProfile())
		protected.POST("/users/block/:targetId", controllers.BlockUser())
		protected.POST("/users/unmatch/:targetId", controllers.UnmatchUser())
	}
}
