package workers

import (
	"context"
	"encoding/json"
	"log"
	"movder-backend/config"
	"movder-backend/controllers"
	"movder-backend/models"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type CSVImportMessage struct {
	JobID             string   `json:"jobId"`
	UserID            string   `json:"userId"`
	Strategy          string   `json:"strategy"`
	SelectedListNames []string `json:"selectedListNames,omitempty"`
}

// StartCSVWorker starts the consumer loop for processing CSV files
func StartCSVWorker() {
	if config.RabbitMQManagerInstance == nil {
		log.Println("⚠️ RabbitMQ Manager başlatılmadı, CSV Worker çalışamıyor.")
		return
	}

	log.Println("🚀 CSV Import Worker başlatılıyor...")

	// Tüketici başlat
	err := config.RabbitMQManagerInstance.Consume(
		"csv_import_queue",
		"csv_worker_1",
		func(msg amqp.Delivery) bool {
			return processCSVMessage(msg)
		},
	)

	if err != nil {
		log.Printf("❌ CSV Worker başlatılamadı: %v", err)
	}
}

func processCSVMessage(msg amqp.Delivery) bool {
	var data CSVImportMessage
	if err := json.Unmarshal(msg.Body, &data); err != nil {
		log.Printf("⚠️ CSV Worker: Geçersiz mesaj formatı: %v", err)
		return true // Hatalı mesaj, tekrar denemeye gerek yok
	}

	ctx := context.Background()
	coll := config.GetCollection(config.DB, "import_jobs")
	objID, err := primitive.ObjectIDFromHex(data.JobID)
	if err != nil {
		log.Printf("⚠️ CSV Worker: Geçersiz Job ID: %s", data.JobID)
		return true
	}

	// Job durumunu processing yap
	_, err = coll.UpdateOne(ctx, bson.M{"_id": objID}, bson.M{"$set": bson.M{"status": "processing", "updatedAt": time.Now()}})
	if err != nil {
		log.Printf("⚠️ CSV Worker: State güncellenemedi: %v", err)
		return false // Retry
	}

	var job models.ImportJob
	if err := coll.FindOne(ctx, bson.M{"_id": objID}).Decode(&job); err != nil {
		log.Printf("⚠️ CSV Worker: Job bulunamadı: %v", err)
		return true
	}

	// Eski parse mantığını çağıracağız (controllers içinden public olanı)
	// payload'dan parseLetterboxdPayloadPublic (bunu public yapacağız) kullanılarak liste taranacak
	parsedLists, warnings, err := controllers.ParseLetterboxdPayloadPublic(job.Payload, job.FileName)
	if err != nil {
		log.Printf("❌ CSV Worker: Ayrıştırma hatası: %v", err)
		coll.UpdateOne(ctx, bson.M{"_id": objID}, bson.M{"$set": bson.M{
			"status":    "failed",
			"logs":      []string{err.Error()},
			"updatedAt": time.Now(),
		}})
		return true // Dosya bozuk, retry etmeye gerek yok
	}

	selectedNames := data.SelectedListNames
	if len(selectedNames) == 0 {
		selectedNames = job.SelectedListNames
	}
	if len(selectedNames) > 0 {
		allowed := make(map[string]struct{}, len(selectedNames))
		for _, name := range selectedNames {
			trimmed := strings.TrimSpace(strings.ToLower(name))
			if trimmed != "" {
				allowed[trimmed] = struct{}{}
			}
		}
		if len(allowed) > 0 {
			filtered := parsedLists[:0]
			for _, pl := range parsedLists {
				if _, ok := allowed[strings.TrimSpace(strings.ToLower(pl.Name))]; ok {
					filtered = append(filtered, pl)
				}
			}
			parsedLists = filtered
		}
	}

	totalItems := 0
	for _, pl := range parsedLists {
		totalItems += len(pl.Items)
	}

	// Job tablosunu toplam sayı ile güncelle
	coll.UpdateOne(ctx, bson.M{"_id": objID}, bson.M{"$set": bson.M{
		"totalItems": totalItems,
		"logs":       warnings,
	}})

	// Artık MongoDB Commit (Kaydetme) Mantığı
	processedItems := 0
	failedItems := 0

	for _, incoming := range parsedLists {
		listID, _, err := controllers.ResolveTargetListPublic(ctx, config.GetCollection(config.DB, "lists"), config.GetCollection(config.DB, "list_items"), data.UserID, incoming, data.Strategy)
		if err != nil {
			log.Printf("⚠️ CSV Worker: Liste çözümlenemedi: %v", err)
			continue
		}

		for _, item := range incoming.Items {
			// TMDB API Limit Koruması
			time.Sleep(100 * time.Millisecond) // Biraz yavaşlat

			controllers.MatchTMDBMoviePublic(&item)

			if item.TmdbID == 0 {
				failedItems++
			} else {
				// DB'ye yaz
				_, _ = config.GetCollection(config.DB, "list_items").InsertOne(ctx, models.ListItem{
					ListID:    listID,
					Position:  item.Position,
					TmdbID:    item.TmdbID,
					MovieName: item.MovieName,
					PosterURL: item.PosterURL,
					AddedAt:   time.Now(),
				})
				processedItems++
			}

			// Her 10 item'da bir progress update
			if (processedItems+failedItems)%10 == 0 {
				progress := int((float64(processedItems+failedItems) / float64(totalItems)) * 100)
				coll.UpdateOne(ctx, bson.M{"_id": objID}, bson.M{"$set": bson.M{
					"processedItems": processedItems,
					"failedItems":    failedItems,
					"progress":       progress,
					"updatedAt":      time.Now(),
				}})
			}
		}

		// Liste güncellendi tarihi tazele
		config.GetCollection(config.DB, "lists").UpdateOne(ctx, bson.M{"_id": listID}, bson.M{"$set": bson.M{"updatedAt": time.Now()}})
	}

	// Bittiğinde
	coll.UpdateOne(ctx, bson.M{"_id": objID}, bson.M{"$set": bson.M{
		"status":         "completed",
		"processedItems": processedItems,
		"failedItems":    failedItems,
		"progress":       100,
		"updatedAt":      time.Now(),
	}})

	// User document flag update
	userIDObj, _ := primitive.ObjectIDFromHex(data.UserID)
	config.GetCollection(config.DB, "users").UpdateOne(ctx, bson.M{"_id": userIDObj}, bson.M{"$set": bson.M{"letterboxd_imported": true}})

	// Bildirim gönder (RabbitMQ gereksiz şu an lokalde atıyoruz, bildirim manager da çağırılabilir)
	// Burada bir notification tablosu kaydı atalım
	config.GetCollection(config.DB, "notifications").InsertOne(ctx, bson.M{
		"userId":    data.UserID,
		"type":      "system",
		"title":     "İçe Aktarım Tamamlandı",
		"message":   "Letterboxd dizilerini aktarma işlemi başarıyla sona erdi.",
		"isRead":    false,
		"createdAt": time.Now(),
	})

	log.Printf("✅ CSV Worker İşlemi Tamamlandı: %s, Processed: %d, Failed: %d", data.JobID, processedItems, failedItems)
	return true
}
