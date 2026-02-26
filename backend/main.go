package main

import (
	"fmt"
	"movder-backend/config"
	"movder-backend/routes"

	"github.com/gin-gonic/gin"
)

func main() {
	// 1. Ortam değişkenlerini yükle (.env)
	config.LoadEnv()

	// 2. Veritabanlarını ve servisleri başlat
	config.ConnectDB()
	config.ConnectRedis()
	config.ConnectRabbitMQ()

	// 3. Gin motorunu oluştur
	r := gin.Default()

	// 4. Rotaları sisteme tanıt
	routes.UserRoutes(r)   // /register, /login, /api/profile
	routes.TmdbRoutes(r)   // /search, /movie/:id, /trending
	routes.StatusRoutes(r) // /api/status (POST, GET, DELETE)
	routes.MatchRoutes(r)  // /api/match/check
	routes.ChatRoutes(r)   // /ws/chat/:roomId
	routes.ListRoutes(r)   // /api/lists

	// 5. Sağlık kontrolü endpoint'i
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{"mesaj": "Movder API - Profesyonel Mimari Aktif!"})
	})

	// 6. Motoru ateşle
	fmt.Println("🚀 Movder Sunucusu 8080 portunda çalışıyor...")
	r.Run(":8080")
}
