package main

import (
	"movder-backend/config"
	"movder-backend/routes"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	// Veritabanını başlat
	config.ConnectDB()

	// Rotaları sisteme tanıt
	routes.UserRoutes(r)

	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{"mesaj": "Movder API - Profesyonel Mimari Aktif!"})
	})

	r.Run(":8080")
}
