package routes

import (
	"movder-backend/controllers"
	"movder-backend/middleware"

	"github.com/gin-gonic/gin"
)

func ListRoutes(r *gin.Engine) {
	lists := r.Group("/api/lists")
	lists.Use(middleware.AuthMiddleware()) // Sadece giriş yapmış kullanıcılar kategori oluşturabilir ve ekleyebilir
	{
		// Liste Yönetimi
		lists.POST("/", controllers.CreateList())  // Yeni liste (kategori) oluştur
		lists.GET("/my", controllers.GetMyLists()) // Kendi listelerimi getir

		// Liste İçi Öğe (Film) Yönetimi
		lists.POST("/items", controllers.AddMovieToList())  // Bir listeye film ekle
		lists.GET("/:id/items", controllers.GetListItems()) // Bir listenin filmlerini getir
	}
}
