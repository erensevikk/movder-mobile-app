package routes

import (
	"movder-backend/controllers"

	"github.com/gin-gonic/gin"
)

func TmdbRoutes(r *gin.Engine) {
	r.GET("/search", controllers.SearchMovies())
	r.GET("/movie/:id", controllers.GetMovieDetails())
	r.GET("/trending", controllers.GetTrending())
	r.GET("/discover", controllers.GetDiscoverMovies())
}
