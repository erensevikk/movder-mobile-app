package config

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var DB *mongo.Client

func ConnectDB() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Bağlantı bilgisi artık .env dosyasından okunuyor — hardcoded değil
	mongoURI := GetEnv("MONGODB_URI", "mongodb://admin:password123@localhost:27017")
	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatal("Bağlantı hatası: ", err)
	}

	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatal("MongoDB ulaşılamaz durumda: ", err)
	}

	fmt.Println("✅ Veritabanı bağlantısı config üzerinden sağlandı.")
	DB = client
}

// Koleksiyonlara erişmek için yardımcı fonksiyon
func GetCollection(client *mongo.Client, collectionName string) *mongo.Collection {
	return client.Database("movderDB").Collection(collectionName)
}
