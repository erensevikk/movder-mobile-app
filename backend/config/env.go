package config

import (
	"log"
	"os"
	"strings"

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

// IsDocker true döner eğer uygulama Docker container içinde çalışıyorsa
func IsDocker() bool {
	// /.dockerenv dosyası veya DOCKER_HOST ortam değişkeni kontrolü
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return true
	}
	if os.Getenv("DOCKER_HOST") != "" {
		return true
	}
	// Container ortamında genellikle PATH bu şekilde başlar
	if strings.Contains(os.Getenv("PATH"), "/docker/containers/") {
		return true
	}
	return false
}

// GetMongoHost MongoDB host adresini döner (Docker veya local)
func GetMongoHost() string {
	if IsDocker() {
		return GetEnv("MONGO_HOST", "mongodb")
	}
	return GetEnv("MONGO_HOST", "localhost")
}

// GetRedisHost Redis host adresini döner (Docker veya local)
func GetRedisHost() string {
	if IsDocker() {
		return GetEnv("REDIS_HOST", "redis")
	}
	return GetEnv("REDIS_HOST", "localhost")
}

// GetRabbitMQHost RabbitMQ host adresini döner (Docker veya local)
func GetRabbitMQHost() string {
	if IsDocker() {
		return GetEnv("RABBITMQ_HOST", "rabbitmq")
	}
	return GetEnv("RABBITMQ_HOST", "localhost")
}

// GetAllowedOrigins WebSocket için izin verilen origin'leri döner (comma-separated)
func GetAllowedOrigins() string {
	return GetEnv("ALLOWED_ORIGINS", "*")
}

// IsOriginAllowed Verilen origin'in izin verilenler listesinde olup olmadığını kontrol eder
func IsOriginAllowed(origin string) bool {
	allowed := GetAllowedOrigins()
	if allowed == "*" {
		// Development: tüm origin'lere izin ver
		return true
	}
	if allowed == "" {
		return false
	}

	// Split by comma and check
	origins := strings.Split(allowed, ",")
	origin = strings.TrimSpace(origin)
	for _, o := range origins {
		if strings.TrimSpace(o) == origin {
			return true
		}
	}
	return false
}
