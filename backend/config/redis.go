package config

import (
	"context"
	"fmt"
	"log"

	"github.com/redis/go-redis/v9"
)

var RedisClient *redis.Client

func ConnectRedis() {
	redisURI := GetEnv("REDIS_URI", "redis://:redispass123@localhost:6379")

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
