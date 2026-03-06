package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"movder-backend/config"
	"strconv"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// MatchRequest — Eşleşme kuyruğuna gönderilen mesaj
type MatchRequest struct {
	UserID    string `json:"userId"`
	Username  string `json:"username"`
	City      string `json:"city"`
	LocalOnly bool   `json:"localOnly"`
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

// CheckForMatch — Eşleşme olup olmadığını RabbitMQ kuyruğuna bakarak kontrol eder
func CheckForMatch(userId string, tmdbID int, localOnly bool) (*MatchResult, error) {
	ctx := context.Background()
	userCol := config.GetCollection(config.DB, "users")

	// Kullanıcı başına aktif arama lock'u (aynı anda birden fazla CheckForMatch çalışmasın)
	lockKey := fmt.Sprintf("match_lock:%s:%d", userId, tmdbID)
	ok, err := config.RedisClient.SetNX(ctx, lockKey, time.Now().Unix(), 30*time.Second).Result()
	if err != nil {
		log.Printf("⚠️ match lock set error userId=%s tmdbId=%d err=%v", userId, tmdbID, err)
	} else if !ok {
		// Aynı kullanıcı için bu filmde zaten aktif bir arama var; ekstra yük oluşturmayalım
		log.Printf("🔁 match already in progress userId=%s tmdbId=%d", userId, tmdbID)
		return nil, nil
	}
	defer config.RedisClient.Del(ctx, lockKey)

	// Kuyruğa girdiğini / aktif beklediğini Redis ZSet ile bildir (Zaman bazlı aktiflik kontrolü)
	config.RedisClient.ZAdd(ctx, "match_queue_active", redis.Z{
		Score:  float64(time.Now().Unix()),
		Member: userId,
	})

	// 1. Önce, başkası beni seçip eşleşme yaratmış mı ona bakalım (Ben kuyruktaykenden o beni çektiyse)
	myMatchKey := fmt.Sprintf("user_match:%s", userId)
	if matchData, err := config.RedisClient.Get(ctx, myMatchKey).Result(); err == nil {
		var result MatchResult
		if err := json.Unmarshal([]byte(matchData), &result); err == nil {
			// Eşleşme bulundu, Redis'teki key'i silebiliriz ki bir daha sürekli çıkmasın
			// Frontend her zaman user2Name'i "karşı taraf" olarak okuyor.
			// Bu yüzden User1 ile User2'nin yerlerini değiştirerek dönüyoruz.
			swapped := MatchResult{
				RoomID:    result.RoomID,
				User1ID:   result.User2ID,
				User1Name: result.User2Name,
				User2ID:   result.User1ID,
				User2Name: result.User1Name,
				TmdbID:    result.TmdbID,
				MovieName: result.MovieName,
			}
			return &swapped, nil
		}
	}

	queueName := fmt.Sprintf("match_queue_%d", tmdbID)

	// Kuyruğu garanti altına alalım
	_, err = config.RabbitChannel.QueueDeclare(queueName, false, true, false, false, nil)
	if err != nil {
		return nil, err
	}

	// Kendi bilgilerimi al (Unmatched kontrolü ve Publish için)
	var myUser struct {
		Username       string               `bson:"username"`
		City           string               `bson:"city"`
		UnmatchedUsers []primitive.ObjectID `bson:"unmatched_users"`
	}
	myObjID, _ := primitive.ObjectIDFromHex(userId)
	_ = userCol.FindOne(ctx, bson.M{"_id": myObjID}).Decode(&myUser)

	// My watching status for MovieName
	watchKey := fmt.Sprintf("watching:%s", userId)
	data, _ := config.RedisClient.Get(ctx, watchKey).Result()
	var myStatus struct {
		MovieName string `json:"movieName"`
	}
	json.Unmarshal([]byte(data), &myStatus)

	// Eşleşme araması devam ettiği sürece izleme durumunun süresini tazele
	// (heartbeat aralığından bağımsız olarak TTL'in dolmasını engelle)
	if data != "" {
		config.RedisClient.Expire(ctx, watchKey, 15*time.Minute)
	}

	var matchedReq *MatchRequest
	var matchDeliveryTag uint64
	var nackedTags []uint64
	sawMyself := false

	// Mesajları kuyruktan çekelim (maksimum 10 kişiye bakar)
	for i := 0; i < 10; i++ {
		msg, ok, err := config.RabbitChannel.Get(queueName, false)
		if err != nil || !ok {
			break
		}

		var req MatchRequest
		if err := json.Unmarshal(msg.Body, &req); err != nil {
			config.RabbitChannel.Nack(msg.DeliveryTag, false, false) // Hatalı mesaj çöpe
			continue
		}

		// Kullanıcı bu istekten sonra "iptal" tuşuna bastıysa, kuyruğu kaba temizlemek yerine
		// iptal flag'ine bakarak sadece ilgili mesajı düşük maliyetle çöpe atıyoruz.
		cancelKey := fmt.Sprintf("match_cancelled:%s:%d", req.UserID, req.TmdbID)
		if val, err := config.RedisClient.Get(ctx, cancelKey).Result(); err == nil && val == "1" {
			// Bu istek iptal edilmiş, kalıcı olarak sil
			_ = config.RabbitChannel.Ack(msg.DeliveryTag, false)
			continue
		}

		if req.UserID == userId {
			sawMyself = true
			// HATA DÜZELTME: Kendi mesajımızı tekrar kuyruğa koymak (nack) yerine,
			// kalıcı olarak silmeliyiz (ack). Yoksa iptal-arama döngüsünde hatalı eski isteklerle kendimizle eşleşiriz.
			_ = config.RabbitChannel.Ack(msg.DeliveryTag, false)
			continue
		}

		targetID, _ := primitive.ObjectIDFromHex(req.UserID)

		// Engellenme Kontrolü
		blockedCount, _ := userCol.CountDocuments(ctx, bson.M{
			"$or": bson.A{
				bson.M{"_id": myObjID, "blocked_users": targetID},
				bson.M{"_id": targetID, "blocked_users": myObjID},
			},
		})

		if blockedCount > 0 {
			nackedTags = append(nackedTags, msg.DeliveryTag)
			continue
		}

		// Aynı şehir filtresi:
		// Taraflardan biri "şehrimde ara" modundaysa şehirler birebir eşleşmeli.
		if localOnly || req.LocalOnly {
			myCity := strings.TrimSpace(strings.ToLower(myUser.City))
			targetCity := strings.TrimSpace(strings.ToLower(req.City))
			if myCity == "" || targetCity == "" || myCity != targetCity {
				nackedTags = append(nackedTags, msg.DeliveryTag)
				continue
			}
		}

		// Öncelikli Eşleşme (History-Based Matching)
		// Daha önce unmatch yapılmış mı?
		unmatchedPrior := false
		for _, uID := range myUser.UnmatchedUsers {
			if uID == targetID {
				unmatchedPrior = true
				break
			}
		}

		// Karşı taraf beni unmatch yaptıysa onlardan da kontrol edebiliriz ama
		// user_controller.go içinde UnmatchUser yapıldığında ZATEN İKİ TARAF DA BİRBİRİNE EKLENDİ.
		// Yani kendi listemde varsa o zaten beni unmatch listesine eklemiştir. Mükemmel.

		// Olasılık zarı: Hiç eşleşmemiş için %50 (veya direkt %100 yapabiliriz ama planda 50 dediniz)
		// Plandaki örnek: "Hiç eşleşmemiş %50, iptal edilmiş %25".
		// Bu demek oluyor ki normalde bile %50 şansla eşleşiyor, geçmişi varsa %25.
		// Random yerine zaman damgası / math.rand kullanabiliriz.
		// math/rand kütüphanesini kullanmamız lazım. Time bazlı random:
		randVal := time.Now().UnixNano() % 100 // 0-99 arası
		threshold := int64(50)                // No history = 50%
		if unmatchedPrior {
			threshold = 25 // History = 25% chance
		}

		if randVal >= threshold { // thresh 50 ise (50-99 arası reject) -> %50 fail.
			nackedTags = append(nackedTags, msg.DeliveryTag)
			continue
		}

		// EŞLEŞTİK!
		matchedReq = &req
		matchDeliveryTag = msg.DeliveryTag
		break
	}

	// Bakılan ve eşleşilmeyen (veya kendim olan) mesajları kuyruğa iade et
	for _, tag := range nackedTags {
		_ = config.RabbitChannel.Nack(tag, false, true) // requeue = true
	}

	if matchedReq != nil {
		// Mesajı tüket
		_ = config.RabbitChannel.Ack(matchDeliveryTag, false)

		roomID := primitive.NewObjectID().Hex()

		result := &MatchResult{
			RoomID:    roomID,
			User1ID:   userId,
			User1Name: myUser.Username,
			User2ID:   matchedReq.UserID,
			User2Name: matchedReq.Username,
			TmdbID:    tmdbID,
			MovieName: myStatus.MovieName,
		}

		answerJSON, _ := json.Marshal(result)

		// Odayı Redis'e kaydet
		config.RedisClient.Set(ctx, "chatroom:"+roomID, answerJSON, 4*time.Hour)

		// Karşı tarafın poll'layabilmesi için onun adıyla Redis'e 15 saniyeliğine kaydet
		config.RedisClient.Set(ctx, "user_match:"+matchedReq.UserID, answerJSON, 15*time.Second)

		// Eşleşme sağlandığı için bekleyenler listesinden ikisini de çıkar
		config.RedisClient.ZRem(ctx, "match_queue_active", userId, matchedReq.UserID)

		log.Printf("🎉 RabbitMQ Match! %s ↔ %s (%s)", myUser.Username, matchedReq.Username, myStatus.MovieName)
		return result, nil
	}

	// Kuyrukta kendimizi bile görmediysek ve eşleşmediysek talebimizi Publish edelim (Yani kuyruğa biz de girelim)
	if !sawMyself {
		req := MatchRequest{
			UserID:    userId,
			Username:  myUser.Username,
			City:      myUser.City,
			LocalOnly: localOnly,
			TmdbID:    tmdbID,
			MovieName: myStatus.MovieName,
			Timestamp: time.Now().Unix(),
		}
		_ = PublishMatchRequest(req)
	}

	return nil, nil
}

// CancelMatchRequest — Eşleşme aramasını iptal eder.
// Kuyruk taramak yerine, "cancel marker" yazarız; tüketim sırasında bu flag'e bakılıp
// ilgili mesajlar düşük maliyetle ayıklanır.
func CancelMatchRequest(userId string, tmdbID int) error {
	ctx := context.Background()

	// Bu kullanıcının bu film için aktif talebinin iptal edildiğini işaretle
	cancelKey := fmt.Sprintf("match_cancelled:%s:%d", userId, tmdbID)
	if err := config.RedisClient.Set(ctx, cancelKey, "1", 2*time.Minute).Err(); err != nil {
		log.Printf("⚠️ match cancel marker set failed userId=%s tmdbId=%d err=%v", userId, tmdbID, err)
	}

	// Bekleyenler listesinden çıkar
	config.RedisClient.ZRem(ctx, "match_queue_active", userId)

	log.Printf("🛑 Eşleşme araması iptal edildi: %s (cancel marker yazıldı)", userId)
	return nil
}

// GetTotalQueueCount — Şu anda aktif olarak eşleşme arayan (kuyrukta olan) kullanıcı sayısını getirir
func GetTotalQueueCount() (int, error) {
	ctx := context.Background()

	// Zamanı geçenleri (1 dakikadan eski pingleri) bekleyenlerden temizle
	minScore := "-inf"
	maxScore := strconv.FormatInt(time.Now().Add(-1*time.Minute).Unix(), 10)
	config.RedisClient.ZRemRangeByScore(ctx, "match_queue_active", minScore, maxScore)

	// Kalan taze eleman (aktif arayan) sayısını say
	count, err := config.RedisClient.ZCard(ctx, "match_queue_active").Result()
	if err != nil {
		return 0, err
	}
	return int(count), nil
}

// AcceptMatchAndGetRoom — Kullanıcı eşleşmeyi kabul ettiğinde çağrılır.
// Her iki taraf kabul edince, odaDaha önce sohbet varsa onu döner, yoksa yeni oda oluşturulmuştur.
// Strateji: Redis'e accept:{roomId}:{userId} = "1" olarak 90 saniye yazılır.
// Her iki kullanıcı yazılmışsa → "bothAccepted: true, roomId: ..."
// Bot: Kabul edilmeden önce süresi dolan key silinir.
func AcceptMatchAndGetRoom(userId, roomID, targetUserId string) (map[string]interface{}, error) {
	ctx := context.Background()

	// Kendi kabul key'ini yaz (10 dakika geçerli — güvenli süre)
	acceptKey := fmt.Sprintf("accept:%s:%s", roomID, userId)
	config.RedisClient.Set(ctx, acceptKey, "1", 10*time.Minute)

	// Karşı tarafın da kabul edip etmediğini kontrol et
	targetAcceptKey := fmt.Sprintf("accept:%s:%s", roomID, targetUserId)
	targetVal, err := config.RedisClient.Get(ctx, targetAcceptKey).Result()
	bothAccepted := err == nil && targetVal == "1"

	if bothAccepted {
		// İkisi de kabul etti → mevcut sohbet oda varsa bul, yoksa yeni oluştur
		finalRoomID, err := getOrCreateChatRoom(ctx, userId, targetUserId, roomID)
		if err != nil {
			return nil, err
		}
		return map[string]interface{}{
			"bothAccepted": true,
			"roomId":       finalRoomID,
		}, nil
	}

	// Sadece ben kabul ettim, karşı taraf henüz kabul etmedi
	return map[string]interface{}{
		"bothAccepted": false,
		"roomId":       "",
	}, nil
}

// GetAcceptStatus — Polling için: karşı taraf kabul etti mi?
// Query: roomId, targetUserId
func GetAcceptStatus(userId, roomID string) (map[string]interface{}, error) {
	ctx := context.Background()

	// Önce red kontrolü yap
	rejectedKey := "rejected:" + roomID
	if val, err := config.RedisClient.Get(ctx, rejectedKey).Result(); err == nil && val == "1" {
		return map[string]interface{}{"bothAccepted": false, "rejected": true}, nil
	}

	// Oda kaydından targetUserId'yi bul
	chatroomKey := "chatroom:" + roomID
	roomData, err := config.RedisClient.Get(ctx, chatroomKey).Result()
	if err != nil {
		return map[string]interface{}{"bothAccepted": false}, nil
	}

	var matchResult MatchResult
	if err := json.Unmarshal([]byte(roomData), &matchResult); err != nil {
		return map[string]interface{}{"bothAccepted": false}, nil
	}

	// targetUserId = karşı taraf
	targetUserId := matchResult.User2ID
	if targetUserId == userId {
		targetUserId = matchResult.User1ID
	}

	// Karşı tarafın accept key'ini kontrol et
	targetAcceptKey := fmt.Sprintf("accept:%s:%s", roomID, targetUserId)
	targetVal, err := config.RedisClient.Get(ctx, targetAcceptKey).Result()
	if err != nil || targetVal != "1" {
		return map[string]interface{}{"bothAccepted": false}, nil
	}

	// İkisi de kabul etti
	finalRoomID, err := getOrCreateChatRoom(ctx, userId, targetUserId, roomID)
	if err != nil {
		return nil, err
	}

	return map[string]interface{}{
		"bothAccepted": true,
		"roomId":       finalRoomID,
	}, nil
}

// getOrCreateChatRoom — İki kullanıcı arasında daha önce sohbet odası varsa döner, yoksa var olanı kullanır.
// MongoDB'deki "chatrooms" koleksiyonunda user pair bazlı arama yapar.
func getOrCreateChatRoom(ctx context.Context, userId, targetUserId, fallbackRoomID string) (string, error) {
	col := config.GetCollection(config.DB, "chatrooms")

	// Sıralamadan bağımsız eşleşme: her iki permütasyonu da ara
	filter := bson.M{
		"$or": bson.A{
			bson.M{"user1Id": userId, "user2Id": targetUserId},
			bson.M{"user1Id": targetUserId, "user2Id": userId},
		},
	}

	var existing struct {
		RoomID string `bson:"roomId"`
	}
	err := col.FindOne(ctx, filter).Decode(&existing)
	if err == nil && existing.RoomID != "" {
		// Debug: mevcut oda bulunursa hangi metadata ile dönüldüğünü gözlemle
		var existingRoomMeta struct {
			RoomID    string `bson:"roomId"`
			User1ID   string `bson:"user1Id"`
			User2ID   string `bson:"user2Id"`
			MovieName string `bson:"movieName"`
			PosterURL string `bson:"posterUrl"`
			Status    string `bson:"status"`
		}
		if errMeta := col.FindOne(ctx, bson.M{"roomId": existing.RoomID}).Decode(&existingRoomMeta); errMeta != nil {
			log.Printf("🔎 getOrCreateChatRoom existing room meta read failed roomId=%s err=%v", existing.RoomID, errMeta)
		} else {
			log.Printf("🔎 getOrCreateChatRoom reusing existing room roomId=%s user1Id=%s user2Id=%s status=%q movieName=%q posterUrlEmpty=%t", existingRoomMeta.RoomID, existingRoomMeta.User1ID, existingRoomMeta.User2ID, existingRoomMeta.Status, existingRoomMeta.MovieName, strings.TrimSpace(existingRoomMeta.PosterURL) == "")
		}
		// Daha önce sohbet edilmiş oda tekrar kullanılıyor.
		// Eğer geçmişte unmatch nedeniyle status "unmatched" kaldıysa,
		// yeni eşleşmede aktif sohbeti açabilmek için status'u resetle.
		if existingRoomMeta.Status == "unmatched" {
			updateRes, updateErr := col.UpdateOne(
				ctx,
				bson.M{"roomId": existing.RoomID},
				bson.M{
					"$set": bson.M{
						"status":    "matched",
						"updatedAt": time.Now(),
					},
					"$unset": bson.M{
						"unmatchedBy": "",
						"unmatchedAt": "",
					},
				},
			)
			_ = updateRes
			if updateErr != nil {
				log.Printf("⚠️ getOrCreateChatRoom stale unmatched status reset failed roomId=%s err=%v", existing.RoomID, updateErr)
			}
		}

		// Daha önce sohbet edilmiş → aynı odayı döndür
		return existing.RoomID, nil
	}

	// İlk kez eşleşiyorlar → fallbackRoomID'yi MongoDB'ye kaydet ve döndür
	// Redis'teki chatroom key'inden film bilgisini çek
	var movieName, posterUrl string
	if roomData, err2 := config.RedisClient.Get(ctx, "chatroom:"+fallbackRoomID).Result(); err2 == nil {
		var matchResult MatchResult
		if errUnmarshal := json.Unmarshal([]byte(roomData), &matchResult); errUnmarshal == nil {
			movieName = matchResult.MovieName
			log.Printf("🔎 getOrCreateChatRoom redis chatroom hit roomId=%s movieName=%q", fallbackRoomID, movieName)
		} else {
			log.Printf("🔎 getOrCreateChatRoom redis chatroom decode failed roomId=%s err=%v", fallbackRoomID, errUnmarshal)
		}
	} else {
		log.Printf("🔎 getOrCreateChatRoom redis chatroom miss roomId=%s err=%v", fallbackRoomID, err2)
	}
	insertRes, insertErr := col.InsertOne(ctx, bson.M{
		"roomId":    fallbackRoomID,
		"user1Id":   userId,
		"user2Id":   targetUserId,
		"movieName": movieName,
		"posterUrl": posterUrl,
		"createdAt": time.Now(),
	})
	if insertErr != nil {
		log.Printf("🔎 getOrCreateChatRoom insert failed roomId=%s user1Id=%s user2Id=%s movieName=%q err=%v", fallbackRoomID, userId, targetUserId, movieName, insertErr)
	} else {
		log.Printf("🔎 getOrCreateChatRoom inserted roomId=%s insertedId=%v movieName=%q posterUrlEmpty=%t", fallbackRoomID, insertRes.InsertedID, movieName, strings.TrimSpace(posterUrl) == "")

		var user1, user2 struct {
			Username  string `bson:"username"`
			AvatarURL string `bson:"avatarUrl"`
		}
		userCol := config.GetCollection(config.DB, "users")

		objId1, _ := primitive.ObjectIDFromHex(userId)
		objId2, _ := primitive.ObjectIDFromHex(targetUserId)

		_ = userCol.FindOne(ctx, bson.M{"_id": objId1}).Decode(&user1)
		_ = userCol.FindOne(ctx, bson.M{"_id": objId2}).Decode(&user2)

		notifCol := config.GetCollection(config.DB, "notifications")
		messageStr1 := fmt.Sprintf("%s ile %s filmini izlerken eşleştiniz!", user2.Username, movieName)
		messageStr2 := fmt.Sprintf("%s ile %s filmini izlerken eşleştiniz!", user1.Username, movieName)

		_, _ = notifCol.InsertMany(ctx, []interface{}{
			bson.M{
				"userId":    userId,
				"type":      "match",
				"senderId":  targetUserId,
				"title":     "Yeni Eşleşme",
				"message":   messageStr1,
				"avatar":    user2.AvatarURL,
				"isRead":    false,
				"createdAt": time.Now(),
			},
			bson.M{
				"userId":    targetUserId,
				"type":      "match",
				"senderId":  userId,
				"title":     "Yeni Eşleşme",
				"message":   messageStr2,
				"avatar":    user1.AvatarURL,
				"isRead":    false,
				"createdAt": time.Now(),
			},
		})
	}

	// Odanın Redis'te zaten var olduğunu varsay (CheckForMatch sırasında yazıldı)
	log.Printf("💬 Yeni sohbet odası kaydedildi: %s (%s ↔ %s)", fallbackRoomID, userId, targetUserId)
	return fallbackRoomID, nil
}

// RejectMatch — Eşleşmeyi reddeden kullanıcı arama havuzunda kalmaya devam edecek.
// Ancak aynı anda hemen tekrar eşleşmemeleri veya önbellekte aynı eşleşmenin dönmemesi için
// "user_match:userId" Redis key'i temizlenir ve kabul durumu sıfırlanır.
func RejectMatch(userId, roomID, targetUserId string) error {
	ctx := context.Background()

	// 1. Red flag'i koy ki karşı taraf polling ile anında algılasın (30 saniye yeterli)
	rejectedKey := "rejected:" + roomID
	config.RedisClient.Set(ctx, rejectedKey, "1", 30*time.Second)

	// 2. Her iki tarafın "match cache" objesini temizle ki birbirleriyle hemen kilitlenmesinler
	config.RedisClient.Del(ctx, "user_match:"+userId)
	config.RedisClient.Del(ctx, "user_match:"+targetUserId)

	// 3. Kabul eden taraf (target veya biz) "accept" basmış olabilir, onları da temizle
	config.RedisClient.Del(ctx, "accept:"+roomID+":"+userId)
	config.RedisClient.Del(ctx, "accept:"+roomID+":"+targetUserId)
	config.RedisClient.Del(ctx, "chatroom:"+roomID)

	log.Printf("🛑 Eşleşme reddedildi: %s vs %s", userId, targetUserId)
	return nil
}
