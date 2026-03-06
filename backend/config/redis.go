package config

import (
	"context"
	"fmt"
	"log"

	"github.com/redis/go-redis/v9"
)

var RedisClient *redis.Client

func ConnectRedis() {
	// Host adresi: Docker içinde "redis", localde "localhost"
	redisHost := GetRedisHost()
	redisPassword := GetEnv("REDIS_PASSWORD", "redispass123")
	redisPort := GetEnv("REDIS_PORT", "6379")

	// Docker veya local için uygun URI oluştur
	redisURI := GetEnv("REDIS_URI",
		fmt.Sprintf("redis://:%s@%s:%s", redisPassword, redisHost, redisPort))

	log.Printf("[DEBUG] Redis bağlanıyor: host=%s, port=%s", redisHost, redisPort)

	opt, err := redis.ParseURL(redisURI)
	if err != nil {
		log.Fatal("Redis URI parse hatası: ", err)
	}

	RedisClient = redis.NewClient(opt)

	// Bağlantı testi
	ctx := context.Background()
	_, err = RedisClient.Ping(ctx).Result()
	if err != nil {
		log.Fatal("Redis'e ulaşılamıyor (Docker açık mı?): ", err)
	}

	fmt.Println("✅ Redis bağlantısı başarıyla kuruldu.")
}
