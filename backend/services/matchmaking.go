package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"movder-backend/config"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// MatchRequest — Eşleşme kuyruğuna gönderilen mesaj
type MatchRequest struct {
	UserID    string `json:"userId"`
	Username  string `json:"username"`
	TmdbID    int    `json:"tmdbId"`
	MovieName string `json:"movieName"`
	Timestamp int64  `json:"timestamp"`
}

// MatchResult — Eşleşme sonucu
type MatchResult struct {
	RoomID    string `json:"roomId"`
	User1ID   string `json:"user1Id"`
	User1Name string `json:"user1Name"`
	User2ID   string `json:"user2Id"`
	User2Name string `json:"user2Name"`
	TmdbID    int    `json:"tmdbId"`
	MovieName string `json:"movieName"`
}

// PublishMatchRequest — Eşleşme isteğini RabbitMQ kuyruğuna gönderir
func PublishMatchRequest(req MatchRequest) error {
	queueName := fmt.Sprintf("match_queue_%d", req.TmdbID)

	// Kuyruğu oluştur (yoksa)
	_, err := config.RabbitChannel.QueueDeclare(
		queueName, // kuyruk adı
		false,     // durable (kalıcı olmasın — geçici eşleşme verisi)
		true,      // autoDelete (tüketiciler ayrılınca silinsin)
		false,     // exclusive
		false,     // noWait
		nil,       // args
	)
	if err != nil {
		return fmt.Errorf("kuyruk oluşturulamadı: %w", err)
	}

	body, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("mesaj serileştirilemedi: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = config.RabbitChannel.PublishWithContext(ctx,
		"",        // exchange
		queueName, // routing key
		false,     // mandatory
		false,     // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        body,
		},
	)
	if err != nil {
		return fmt.Errorf("mesaj gönderilemedi: %w", err)
	}

	log.Printf("🔍 Eşleşme isteği kuyruğa eklendi: %s → %s", req.Username, req.MovieName)
	return nil
}

// CheckForMatch — Redis'teki izleyici set'ini kontrol ederek eşleşme olup olmadığına bakar
func CheckForMatch(userId string, tmdbID int) (*MatchResult, error) {
	ctx := context.Background()
	userCol := config.GetCollection(config.DB, "users")
	movieKey := fmt.Sprintf("movie:%d:watchers", tmdbID)

	// Bu filmi izleyen diğer kullanıcıları bul
	watchers, err := config.RedisClient.SMembers(ctx, movieKey).Result()
	if err != nil {
		return nil, err
	}

	// Kendisi hariç başka izleyen var mı?
	for _, watcherID := range watchers {
		if watcherID != userId {
			// Eşleşme bulundu, ancak engellenmiş mi kontrol et
			// 1. Kendi engellediğim kişiler arasında mı?
			// 2. Karşı tarafın engellediği kişiler arasında mıyım?

			// ID'leri primitive.ObjectID'ye çevir
			importID, err1 := primitive.ObjectIDFromHex(userId)
			targetID, err2 := primitive.ObjectIDFromHex(watcherID)

			if err1 == nil && err2 == nil {
				// MongoDB'de engellenme durumu varsa atla
				blockedCount, _ := userCol.CountDocuments(ctx, bson.M{
					"$or": bson.A{
						bson.M{"_id": importID, "blocked_users": targetID},
						bson.M{"_id": targetID, "blocked_users": importID},
					},
				})

				if blockedCount > 0 {
					continue // İki kullanıcıdan biri diğerini engellemişse bu eşleşmeyi atla
				}
			}

			// Oda oluştur
			watchKey := fmt.Sprintf("watching:%s", watcherID)
			data, err := config.RedisClient.Get(ctx, watchKey).Result()
			if err != nil {
				continue
			}

			var otherStatus struct {
				Username  string `json:"username"`
				MovieName string `json:"movieName"`
			}
			if err := json.Unmarshal([]byte(data), &otherStatus); err != nil {
				continue
			}

			// Benzersiz oda ID'si oluştur
			roomID := fmt.Sprintf("room_%s_%s_%d", userId, watcherID, time.Now().UnixMilli())

			// Mydata
			myWatchKey := fmt.Sprintf("watching:%s", userId)
			myData, _ := config.RedisClient.Get(ctx, myWatchKey).Result()
			var myStatus struct {
				Username string `json:"username"`
			}
			json.Unmarshal([]byte(myData), &myStatus)

			result := &MatchResult{
				RoomID:    roomID,
				User1ID:   userId,
				User1Name: myStatus.Username,
				User2ID:   watcherID,
				User2Name: otherStatus.Username,
				TmdbID:    tmdbID,
				MovieName: otherStatus.MovieName,
			}

			// Oda bilgisini Redis'e kaydet (TTL: 4 saat)
			roomJSON, _ := json.Marshal(result)
			config.RedisClient.Set(ctx, "chatroom:"+roomID, roomJSON, 4*time.Hour)

			log.Printf("🎉 Eşleşme bulundu! %s ↔ %s (%s)", myStatus.Username, otherStatus.Username, otherStatus.MovieName)
			return result, nil
		}
	}

	return nil, nil // Eşleşme yok
}
