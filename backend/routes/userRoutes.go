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

		// Hesap Ayarları (Account Settings)
		protected.PUT("/account/info", controllers.UpdateAccountInfo())
		protected.PUT("/account/password", controllers.ChangePassword())
		protected.DELETE("/account", controllers.DeleteAccount())

		// Bildirim Ayarları (Notification Settings)
		protected.GET("/account/notifications", controllers.GetNotificationSettings())
		protected.PUT("/account/notifications", controllers.UpdateNotificationSettings())
		protected.GET("/account/privacy", controllers.GetPrivacySettings())
		protected.PUT("/account/privacy", controllers.UpdatePrivacySettings())

		// Engellenen kullanıcılar yönetimi
		protected.GET("/users/blocked", controllers.GetBlockedUsers())
		protected.POST("/users/unblock/:targetId", controllers.UnblockUser())
	}
}
