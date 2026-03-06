package main

import (
	"fmt"
	"log"
	"movder-backend/config"
	"movder-backend/routes"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

func main() {
	wd, _ := os.Getwd()
	envPath, _ := filepath.Abs("../.env")
	log.Printf("[DEBUG] CWD=%s", wd)
	log.Printf("[DEBUG] Expected .env path=%s", envPath)

	// 1. Ortam degiskenlerini yukle (.env)
	config.LoadEnv()
	log.Printf("[DEBUG] FEATURE_LETTERBOXD_IMPORT=%q", config.GetEnv("FEATURE_LETTERBOXD_IMPORT", ""))

	// 2. Veritabanlarini ve servisleri baslat
	config.ConnectDB()
	config.ConnectRedis()
	config.ConnectRabbitMQ()
	if err := config.EnsureUsersCollectionSchema(); err != nil {
		panic("users semasi uygulanamadi: " + err.Error())
	}

	// 3. Gin motorunu oluştur
	r := gin.Default()

	// 4. Rotalari sisteme tanit
	r.Static("/uploads", "./uploads")
	routes.UserRoutes(r)         // /register, /login, /api/profile
	routes.TmdbRoutes(r)         // /search, /movie/:id, /trending
	routes.StatusRoutes(r)       // /api/status (POST, GET, DELETE)
	routes.MatchRoutes(r)        // /api/match/check
	routes.ChatRoutes(r)         // /ws/chat/:roomId
	routes.ListRoutes(r)         // /api/lists
	routes.FriendRoutes(r)       // /api/friends
	routes.NotificationRoutes(r) // /api/notifications

	// 5. Saglik kontrolu endpoint'i
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{"mesaj": "Movder API - Profesyonel Mimari Aktif!"})
	})

	// 6. Motoru atesle
	fmt.Println("Movder Sunucusu 8080 portunda calisiyor...")
	r.Run(":8080")
}
