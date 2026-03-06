package config

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/bson"
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

func EnsureUsersCollectionSchema() error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	db := DB.Database("movderDB")

	// USERS — şema + indexler
	validator := bson.M{
		"$jsonSchema": bson.M{
			"bsonType": "object",
			"required": []string{"username", "email", "password", "city", "birth_date"},
			"properties": bson.M{
				"username":   bson.M{"bsonType": "string", "minLength": 3},
				"email":      bson.M{"bsonType": "string"},
				"password":   bson.M{"bsonType": "string"},
				"city":       bson.M{"bsonType": "string"},
				"birth_date": bson.M{"bsonType": "string"},
			},
		},
	}

	collMod := bson.D{{Key: "collMod", Value: "users"}, {Key: "validator", Value: validator}}
	if err := db.RunCommand(ctx, collMod).Err(); err != nil {
		createCmd := bson.D{{Key: "create", Value: "users"}, {Key: "validator", Value: validator}}
		if createErr := db.RunCommand(ctx, createCmd).Err(); createErr != nil {
			return createErr
		}
	}

	users := db.Collection("users")
	if _, err := users.Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "username", Value: 1}}, Options: options.Index().SetUnique(true)},
		{Keys: bson.D{{Key: "email", Value: 1}}, Options: options.Index().SetUnique(true)},
	}); err != nil {
		return err
	}

	// CHATROOMS — roomId artık ObjectID hex string; unique index + kullanıcı bazlı indexler
	chatrooms := db.Collection("chatrooms")
	if _, err := chatrooms.Indexes().CreateMany(ctx, []mongo.IndexModel{
		// Tekil oda kimliği
		{Keys: bson.D{{Key: "roomId", Value: 1}}, Options: options.Index().SetUnique(true)},
		// İki kullanıcı arasında oda ararken hız
		{Keys: bson.D{{Key: "user1Id", Value: 1}}},
		{Keys: bson.D{{Key: "user2Id", Value: 1}}},
	}); err != nil {
		return err
	}

	// MESSAGES — oda içi mesaj sorguları için kompozit indexler
	messages := db.Collection("messages")
	if _, err := messages.Indexes().CreateMany(ctx, []mongo.IndexModel{
		// Oda + tür + zaman: son mesaj / mesaj listesi
		{Keys: bson.D{{Key: "roomId", Value: 1}, {Key: "type", Value: 1}, {Key: "timestamp", Value: -1}}},
		// Okunmamış / gönderene ve duruma göre filtreli sorgular
		{Keys: bson.D{
			{Key: "roomId", Value: 1},
			{Key: "senderId", Value: 1},
			{Key: "status", Value: 1},
			{Key: "timestamp", Value: -1},
		}},
	}); err != nil {
		return err
	}

	// LISTS — kullanıcı listeleri
	lists := db.Collection("lists")
	if _, err := lists.Indexes().CreateMany(ctx, []mongo.IndexModel{
		// Aynı kullanıcı için liste adı bazlı arama
		{Keys: bson.D{{Key: "userId", Value: 1}, {Key: "name", Value: 1}}},
	}); err != nil {
		return err
	}

	// LIST_ITEMS — liste içi sıralama ve duplicate önleme
	listItems := db.Collection("list_items")
	if _, err := listItems.Indexes().CreateMany(ctx, []mongo.IndexModel{
		// Bir liste içindeki sıralama
		{Keys: bson.D{{Key: "listId", Value: 1}, {Key: "position", Value: 1}}},
		// Aynı film aynı listeye ikinci kez eklenmesin
		{Keys: bson.D{{Key: "listId", Value: 1}, {Key: "tmdbId", Value: 1}}},
	}); err != nil {
		return err
	}

	return nil
}

// Koleksiyonlara erişmek için yardımcı fonksiyon
func GetCollection(client *mongo.Client, collectionName string) *mongo.Collection {
	return client.Database("movderDB").Collection(collectionName)
}
