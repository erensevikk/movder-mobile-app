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
	_, err := users.Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "username", Value: 1}}, Options: options.Index().SetUnique(true)},
		{Keys: bson.D{{Key: "email", Value: 1}}, Options: options.Index().SetUnique(true)},
	})
	return err
}

// Koleksiyonlara erişmek için yardımcı fonksiyon
func GetCollection(client *mongo.Client, collectionName string) *mongo.Collection {
	return client.Database("movderDB").Collection(collectionName)
}
