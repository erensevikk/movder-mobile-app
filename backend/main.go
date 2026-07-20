package main

import (
	"context"
	"fmt"
	"log"
	"movder-backend/config"
	"movder-backend/routes"
	"movder-backend/services"
	"movder-backend/workers"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

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

	// RabbitMQ Manager başlat (yeni mimari)
	config.InitRabbitMQManager()

	// Worker pool'ları başlat (goroutine fan-out öneleme)
	config.InitWorkerPools()

	// Arka plan işçilerini (Workers) başlat
	go workers.StartCSVWorker()

	// Redis tabanlı eşleşme havuzunu başlat
	services.InitCandidatePool()
	services.InitMatchHub()

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

	// 6. Graceful shutdown için signal handling
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-quit
		log.Println("🛑 Shutdown signal alındı, kaynaklar kapatılıyor...")

		// Worker pool'ları kapat
		config.CloseWorkerPools()

		// RabbitMQ kapat
		config.CloseRabbitMQ()

		// Redis kapat
		if config.RedisClient != nil {
			config.RedisClient.Close()
		}

		// MongoDB kapat
		if config.DB != nil {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			config.DB.Disconnect(ctx)
		}

		log.Println("✅ Tüm kaynaklar başarıyla kapatıldı")
		os.Exit(0)
	}()

	// 7. Motoru atesle
	fmt.Println("Movder Sunucusu 8080 portunda calisiyor...")
	r.Run(":8080")
}
