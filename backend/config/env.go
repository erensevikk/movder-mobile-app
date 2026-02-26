package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

// LoadEnv kök dizindeki .env dosyasını yükler
func LoadEnv() {
	// Backend klasöründen çalıştığımız için bir üst dizindeki .env'i okuyoruz
	err := godotenv.Load("../.env")
	if err != nil {
		log.Println("⚠️  .env dosyası bulunamadı, sistem ortam değişkenleri kullanılacak.")
	}
}

// GetEnv ortam değişkenini okur, yoksa varsayılan değeri döner
func GetEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}
