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
		lists.POST("/", controllers.CreateList())              // Yeni liste (kategori) oluştur
		lists.GET("/my", controllers.GetMyLists())             // Kendi listelerimi getir
		lists.GET("/user/:userId", controllers.GetUserLists()) // Belirli bir kullanıcının genel listelerini getir

		// Liste İçi Öğe (Film) Yönetimi
		lists.POST("/items", controllers.AddMovieToList())                        // Bir listeye film ekle
		lists.GET("/:listId/items", controllers.GetListItems())                   // Bir listenin filmlerini getir
		lists.DELETE("/:listId/items/:tmdbId", controllers.RemoveMovieFromList()) // Listeden film sil
		lists.DELETE("/:listId", controllers.DeleteList())                        // Listeyi tamamen sil
		lists.PUT("/:listId/rename", controllers.RenameList())                    // Liste adını değiştir
		lists.PUT("/:listId/reorder", controllers.ReorderList())                  // Liste film sırasını güncelle

		lists.POST("/import/preview", controllers.PreviewLetterboxdImport()) // Letterboxd ZIP/CSV önizleme
		lists.POST("/import/commit", controllers.CommitLetterboxdImport())   // Letterboxd import commit
	}
}
