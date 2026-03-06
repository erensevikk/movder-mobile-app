package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"movder-backend/config"
	"strconv"
	"strings"
	"sync"
	"time"

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

// CandidatePool Redis sorted set tabanlı aday havuzu yöneticisi
type CandidatePool struct {
	mu           sync.RWMutex
	activePools  map[int]*sync.Map // tmdbID -> userID -> MatchRequest
	cleanupTimer *time.Ticker
	ctx          context.Context
	cancel       context.CancelFunc
	wg           sync.WaitGroup
}

var candidatePool *CandidatePool

// NewCandidatePool yeni bir aday havuzu oluşturur
func NewCandidatePool() *CandidatePool {
	ctx, cancel := context.WithCancel(context.Background())
	pool := &CandidatePool{
		activePools: make(map[int]*sync.Map),
		ctx:         ctx,
		cancel:      cancel,
	}

	// Periyodik temizlik başlat (her 30 saniyede bir)
	pool.cleanupTimer = time.NewTicker(30 * time.Second)
	pool.wg.Add(1)
	go pool.cleanupLoop()

	return pool
}

// cleanupLoop eski adayları temizler
func (p *CandidatePool) cleanupLoop() {
	defer p.wg.Done()

	for {
		select {
		case <-p.ctx.Done():
			return
		case <-p.cleanupTimer.C:
			p.cleanup()
		}
	}
}

// cleanup süresi dolmuş adayları temizler
func (p *CandidatePool) cleanup() {
	ctx := context.Background()
	threshold := time.Now().Add(-2 * time.Minute).Unix()

	p.mu.RLock()
	defer p.mu.RUnlock()

	for tmdbID, pool := range p.activePools {
		pool.Range(func(key, value interface{}) bool {
			userID := key.(string)
			req := value.(MatchRequest)

			// Süresi dolmuş mu?
			if req.Timestamp < threshold {
				// Redis'ten da kaldır
				redisKey := fmt.Sprintf("match_candidates:%d", tmdbID)
				config.RedisClient.ZRem(ctx, redisKey, userID)
				pool.Delete(userID)
				log.Printf("🧹 Süresi dolmuş aday temizlendi: %s (tmdbID: %d)", userID, tmdbID)
			}
			return true
		})
	}
}

// AddCandidate aday havuzuna ekler
func (p *CandidatePool) AddCandidate(tmdbID int, req MatchRequest) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if _, ok := p.activePools[tmdbID]; !ok {
		p.activePools[tmdbID] = &sync.Map{}
	}

	p.activePools[tmdbID].Store(req.UserID, req)

	// Redis'e de ekle (yedekleme ve cross-node paylaşım için)
	redisKey := fmt.Sprintf("match_candidates:%d", tmdbID)
	data, _ := json.Marshal(req)
	config.RedisClient.ZAdd(ctx, redisKey, redis.Z{
		Score:  float64(req.Timestamp),
		Member: req.UserID + ":" + string(data),
	})
	// 2 dakika sonra otomatik silinsin
	config.RedisClient.Expire(ctx, redisKey, 2*time.Minute)
}

// RemoveCandidate aday havuzundan kaldırır
func (p *CandidatePool) RemoveCandidate(tmdbID int, userID string) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if pool, ok := p.activePools[tmdbID]; ok {
		pool.Delete(userID)
	}

	// Redis'ten de kaldır
	redisKey := fmt.Sprintf("match_candidates:%d", tmdbID)
	config.RedisClient.ZRem(ctx, redisKey, userID)
}

// FindMatch aday bulur ve eşleştirir
func (p *CandidatePool) FindMatch(tmdbID int, req MatchRequest, myUser *UserInfo) (*MatchResult, error) {
	p.mu.RLock()
	pool, ok := p.activePools[tmdbID]
	p.mu.RUnlock()

	if !ok {
		return nil, nil
	}

	ctx := context.Background()
	userCol := config.GetCollection(config.DB, "users")
	myObjID, _ := primitive.ObjectIDFromHex(req.UserID)

	var matchedReq *MatchRequest

	// Redis'ten adayları al (sıralı - en eski önce)
	redisKey := fmt.Sprintf("match_candidates:%d", tmdbID)
	candidates, err := config.RedisClient.ZRange(ctx, redisKey, 0, -1).Result()
	if err != nil && err != redis.Nil {
		log.Printf("⚠️ Redis aday okuma hatası: %v", err)
	}

	// Önce in-memory havuzunu kontrol et
	pool.Range(func(key, value interface{}) bool {
		candidateID := key.(string)
		candidate := value.(MatchRequest)

		// Kendim değilim?
		if candidateID == req.UserID {
			return true
		}

		// İptal edilmiş mi?
		cancelKey := fmt.Sprintf("match_cancelled:%s:%d", candidateID, tmdbID)
		if val, _ := config.RedisClient.Get(ctx, cancelKey).Result(); val == "1" {
			return true
		}

		// Engellenmiş mi?
		targetID, _ := primitive.ObjectIDFromHex(candidateID)
		blockedCount, _ := userCol.CountDocuments(ctx, bson.M{
			"$or": bson.A{
				bson.M{"_id": myObjID, "blocked_users": targetID},
				bson.M{"_id": targetID, "blocked_users": myObjID},
			},
		})
		if blockedCount > 0 {
			return true
		}

		// Şehir filtresi
		if req.LocalOnly || candidate.LocalOnly {
			myCity := strings.TrimSpace(strings.ToLower(myUser.City))
			targetCity := strings.TrimSpace(strings.ToLower(candidate.City))
			if myCity == "" || targetCity == "" || myCity != targetCity {
				return true
			}
		}

		// Unmatched kontrolü
		unmatchedPrior := false
		for _, uID := range myUser.UnmatchedUsers {
			if uID == targetID {
				unmatchedPrior = true
				break
			}
		}

		// Olasılık kontrolü
		randVal := rand.Intn(100)
		threshold := 50
		if unmatchedPrior {
			threshold = 25
		}
		if randVal >= threshold {
			return true
		}

		// Eşleşme bulundu!
		matchedReq = &candidate
		return false // Döngüyü sonlandır
	})

	if matchedReq == nil && len(candidates) > 0 {
		// Redis'ten bulunan adayları dene
		for _, candidateStr := range candidates {
			// Format: "userID:jsonData"
			idx := strings.Index(candidateStr, ":")
			if idx == -1 {
				continue
			}
			candidateID := candidateStr[:idx]
			candidateData := candidateStr[idx+1:]

			if candidateID == req.UserID {
				continue
			}

			var candidate MatchRequest
			if err := json.Unmarshal([]byte(candidateData), &candidate); err != nil {
				continue
			}

			// Aynı kontroller
			cancelKey := fmt.Sprintf("match_cancelled:%s:%d", candidateID, tmdbID)
			if val, _ := config.RedisClient.Get(ctx, cancelKey).Result(); val == "1" {
				continue
			}

			targetID, _ := primitive.ObjectIDFromHex(candidateID)
			blockedCount, _ := userCol.CountDocuments(ctx, bson.M{
				"$or": bson.A{
					bson.M{"_id": myObjID, "blocked_users": targetID},
					bson.M{"_id": targetID, "blocked_users": myObjID},
				},
			})
			if blockedCount > 0 {
				continue
			}

			if req.LocalOnly || candidate.LocalOnly {
				myCity := strings.TrimSpace(strings.ToLower(myUser.City))
				targetCity := strings.TrimSpace(strings.ToLower(candidate.City))
				if myCity == "" || targetCity == "" || myCity != targetCity {
					continue
				}
			}

			unmatchedPrior := false
			for _, uID := range myUser.UnmatchedUsers {
				if uID == targetID {
					unmatchedPrior = true
					break
				}
			}

			randVal := rand.Intn(100)
			threshold := 50
			if unmatchedPrior {
				threshold = 25
			}
			if randVal >= threshold {
				continue
			}

			matchedReq = &candidate
			break
		}
	}

	if matchedReq == nil {
		return nil, nil
	}

	// Eşleşme oluştur
	roomID := primitive.NewObjectID().Hex()

	result := &MatchResult{
		RoomID:    roomID,
		User1ID:   req.UserID,
		User1Name: req.Username,
		User2ID:   matchedReq.UserID,
		User2Name: matchedReq.Username,
		TmdbID:    tmdbID,
		MovieName: req.MovieName,
	}

	// Her iki adayı da havuzdan kaldır
	p.RemoveCandidate(tmdbID, req.UserID)
	p.RemoveCandidate(tmdbID, matchedReq.UserID)

	// Redis'e eşleşmeyi kaydet
	answerJSON, _ := json.Marshal(result)
	config.RedisClient.Set(ctx, "chatroom:"+roomID, answerJSON, 4*time.Hour)
	config.RedisClient.Set(ctx, "user_match:"+matchedReq.UserID, answerJSON, 15*time.Second)

	log.Printf("🎉 Eşleşme bulundu! %s ↔ %s (%s)", req.Username, matchedReq.Username, req.MovieName)

	return result, nil
}

// GetPoolSize havuzdaki aday sayısını döner
func (p *CandidatePool) GetPoolSize(tmdbID int) int {
	p.mu.RLock()
	defer p.mu.RUnlock()

	if pool, ok := p.activePools[tmdbID]; ok {
		count := 0
		pool.Range(func(key, value interface{}) bool {
			count++
			return true
		})
		return count
	}
	return 0
}

// Stop havuzu durdurur
func (p *CandidatePool) Stop() {
	p.cancel()
	p.cleanupTimer.Stop()
	p.wg.Wait()
	log.Println("🛑 CandidatePool durduruldu")
}

// UserInfo kullanıcı bilgileri
type UserInfo struct {
	Username       string
	City           string
	UnmatchedUsers []primitive.ObjectID
}

var ctx = context.Background()

// InitCandidatePool aday havuzunu başlatır
func InitCandidatePool() {
	candidatePool = NewCandidatePool()
	log.Println("✅ CandidatePool başlatıldı")
}

// PublishMatchRequest — Eşleşme isteğini Redis havuzuna ekler (RabbitMQ yerine)
func PublishMatchRequest(req MatchRequest) error {
	// Redis'te kuyruk olduğunu bildir (toplam sayı için)
	config.RedisClient.ZAdd(ctx, "match_queue_active", redis.Z{
		Score:  float64(time.Now().Unix()),
		Member: fmt.Sprintf("%d:%s", req.TmdbID, req.UserID),
	})

	// Aday havuzuna ekle
	if candidatePool != nil {
		candidatePool.AddCandidate(req.TmdbID, req)
	}

	log.Printf("🔍 Eşleşme isteği havuza eklendi: %s → %s (tmdbID: %d)", req.Username, req.MovieName, req.TmdbID)
	return nil
}

// CheckForMatch — Redis havuzunda eşleşme arar (RabbitMQ polling yerine)
func CheckForMatch(userId string, tmdbID int, localOnly bool) (*MatchResult, error) {
	// Lock kontrolü
	lockKey := fmt.Sprintf("match_lock:%s:%d", userId, tmdbID)
	ok, err := config.RedisClient.SetNX(ctx, lockKey, time.Now().Unix(), 30*time.Second).Result()
	if err != nil {
		log.Printf("⚠️ match lock set error userId=%s tmdbId=%d err=%v", userId, tmdbID, err)
	} else if !ok {
		log.Printf("🔁 match already in progress userId=%s tmdbId=%d", userId, tmdbID)
		return nil, nil
	}
	defer config.RedisClient.Del(ctx, lockKey)

	// Önce bana bir eşleşme gelmiş mi kontrol et
	myMatchKey := fmt.Sprintf("user_match:%s", userId)
	if matchData, err := config.RedisClient.Get(ctx, myMatchKey).Result(); err == nil {
		var result MatchResult
		if err := json.Unmarshal([]byte(matchData), &result); err == nil {
			// User1 ve User2'yi swap et (frontend beklentisi)
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

	// Kullanıcı bilgilerini al
	userCol := config.GetCollection(config.DB, "users")
	myObjID, _ := primitive.ObjectIDFromHex(userId)

	var myUser UserInfo
	err = userCol.FindOne(ctx, bson.M{"_id": myObjID}).Decode(&myUser)
	if err != nil {
		log.Printf("⚠️ Kullanıcı bilgisi alınamadı: %s", userId)
		return nil, err
	}

	// İzleme durumunu al
	watchKey := fmt.Sprintf("watching:%s", userId)
	data, _ := config.RedisClient.Get(ctx, watchKey).Result()
	var myStatus struct {
		MovieName string `json:"movieName"`
	}
	if data != "" {
		json.Unmarshal([]byte(data), &myStatus)
		// TTL'i tazele
		config.RedisClient.Expire(ctx, watchKey, 15*time.Minute)
	}

	// Eşleşme isteği oluştur
	req := MatchRequest{
		UserID:    userId,
		Username:  myUser.Username,
		City:      myUser.City,
		LocalOnly: localOnly,
		TmdbID:    tmdbID,
		MovieName: myStatus.MovieName,
		Timestamp: time.Now().Unix(),
	}

	// Redis havuzunda eşleşme ara
	if candidatePool != nil {
		result, err := candidatePool.FindMatch(tmdbID, req, &myUser)
		if err != nil {
			log.Printf("⚠️ Eşleşme hatası: %v", err)
			// Fallback: RabbitMQ kuyruğuna ekle
			_ = PublishMatchRequest(req)
			return nil, nil
		}
		if result != nil {
			// Aktif listeden kaldır
			config.RedisClient.ZRem(ctx, "match_queue_active", fmt.Sprintf("%d:%s", tmdbID, userId))
			return result, nil
		}
		// Havuzda eşleşme yok, RabbitMQ'ya düş
	} else {
		log.Printf("⚠️ Candidate pool başlatılmamış, RabbitMQ'ya yönlendiriliyor")
	}

	// Eşleşme yok, kendini havuza ekle
	PublishMatchRequest(req)

	return nil, nil
}

// CancelMatchRequest — Eşleşme aramasını iptal eder
func CancelMatchRequest(userId string, tmdbID int) error {
	// İptal işareti koy
	cancelKey := fmt.Sprintf("match_cancelled:%s:%d", userId, tmdbID)
	if err := config.RedisClient.Set(ctx, cancelKey, "1", 2*time.Minute).Err(); err != nil {
		log.Printf("⚠️ match cancel marker set failed userId=%s tmdbId=%d err=%v", userId, tmdbID, err)
	}

	// Havuzdan kaldır
	if candidatePool != nil {
		candidatePool.RemoveCandidate(tmdbID, userId)
	}

	// Aktif listeden kaldır
	config.RedisClient.ZRem(ctx, "match_queue_active", fmt.Sprintf("%d:%s", tmdbID, userId))

	log.Printf("🛑 Eşleşme araması iptal edildi: %s (tmdbID: %d)", userId, tmdbID)
	return nil
}

// GetTotalQueueCount — Aktif eşleşme arayan kullanıcı sayısını döner
func GetTotalQueueCount() (int, error) {
	// Süresi dolmuşları temizle
	minScore := "-inf"
	maxScore := strconv.FormatInt(time.Now().Add(-1*time.Minute).Unix(), 10)
	config.RedisClient.ZRemRangeByScore(ctx, "match_queue_active", minScore, maxScore)

	count, err := config.RedisClient.ZCard(ctx, "match_queue_active").Result()
	if err != nil {
		return 0, err
	}
	return int(count), nil
}

// AcceptMatchAndGetRoom — Kullanıcı eşleşmeyi kabul ettiğinde çağrılır
func AcceptMatchAndGetRoom(userId, roomID, targetUserId string) (map[string]interface{}, error) {
	// Kabul işareti koy
	acceptKey := fmt.Sprintf("accept:%s:%s", roomID, userId)
	config.RedisClient.Set(ctx, acceptKey, "1", 10*time.Minute)

	// Karşı tarafın kabulünü kontrol et
	targetAcceptKey := fmt.Sprintf("accept:%s:%s", roomID, targetUserId)
	targetVal, err := config.RedisClient.Get(ctx, targetAcceptKey).Result()
	bothAccepted := err == nil && targetVal == "1"

	if bothAccepted {
		finalRoomID, err := getOrCreateChatRoom(ctx, userId, targetUserId, roomID)
		if err != nil {
			return nil, err
		}
		return map[string]interface{}{
			"bothAccepted": true,
			"roomId":       finalRoomID,
		}, nil
	}

	return map[string]interface{}{
		"bothAccepted": false,
		"roomId":       "",
	}, nil
}

// GetAcceptStatus — Kabul durumunu sorgular
func GetAcceptStatus(userId, roomID string) (map[string]interface{}, error) {
	// Red kontrolü
	rejectedKey := "rejected:" + roomID
	if val, err := config.RedisClient.Get(ctx, rejectedKey).Result(); err == nil && val == "1" {
		return map[string]interface{}{"bothAccepted": false, "rejected": true}, nil
	}

	// Oda bilgisini al
	chatroomKey := "chatroom:" + roomID
	roomData, err := config.RedisClient.Get(ctx, chatroomKey).Result()
	if err != nil {
		return map[string]interface{}{"bothAccepted": false}, nil
	}

	var matchResult MatchResult
	if err := json.Unmarshal([]byte(roomData), &matchResult); err != nil {
		return map[string]interface{}{"bothAccepted": false}, nil
	}

	// Target user ID
	targetUserId := matchResult.User2ID
	if targetUserId == userId {
		targetUserId = matchResult.User1ID
	}

	// Karşı tarafın kabul durumu
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

// getOrCreateChatRoom — İki kullanıcı arasında sohbet odası oluşturur
func getOrCreateChatRoom(ctx context.Context, userId, targetUserId, fallbackRoomID string) (string, error) {
	col := config.GetCollection(config.DB, "chatrooms")

	// Önceki oda var mı kontrol et
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
		// Mevcut odanın durumunu kontrol et
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
		}

		// Unmatched durumu resetle
		if existingRoomMeta.Status == "unmatched" {
			col.UpdateOne(ctx,
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
				})
		}

		return existing.RoomID, nil
	}

	// Yeni oluştur
	var movieName, posterUrl string
	if roomData, err2 := config.RedisClient.Get(ctx, "chatroom:"+fallbackRoomID).Result(); err2 == nil {
		var matchResult MatchResult
		if errUnmarshal := json.Unmarshal([]byte(roomData), &matchResult); errUnmarshal == nil {
			movieName = matchResult.MovieName
		}
	}

	col.InsertOne(ctx, bson.M{
		"roomId":    fallbackRoomID,
		"user1Id":   userId,
		"user2Id":   targetUserId,
		"movieName": movieName,
		"posterUrl": posterUrl,
		"createdAt": time.Now(),
	})

	// Bildirimler oluştur
	userCol := config.GetCollection(config.DB, "users")
	var user1, user2 struct {
		Username  string `bson:"username"`
		AvatarURL string `bson:"avatarUrl"`
	}

	objId1, _ := primitive.ObjectIDFromHex(userId)
	objId2, _ := primitive.ObjectIDFromHex(targetUserId)

	_ = userCol.FindOne(ctx, bson.M{"_id": objId1}).Decode(&user1)
	_ = userCol.FindOne(ctx, bson.M{"_id": objId2}).Decode(&user2)

	notifCol := config.GetCollection(config.DB, "notifications")
	messageStr1 := fmt.Sprintf("%s ile %s filmini izlerken eşleştiniz!", user2.Username, movieName)
	messageStr2 := fmt.Sprintf("%s ile %s filmini izlerken eşleştiniz!", user1.Username, movieName)

	notifCol.InsertMany(ctx, []interface{}{
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

	log.Printf("💬 Yeni sohbet odası kaydedildi: %s (%s ↔ %s)", fallbackRoomID, userId, targetUserId)
	return fallbackRoomID, nil
}

// RejectMatch — Eşleşmeyi reddeder
func RejectMatch(userId, roomID, targetUserId string) error {
	// Red işareti koy
	rejectedKey := "rejected:" + roomID
	config.RedisClient.Set(ctx, rejectedKey, "1", 30*time.Second)

	// Cache'leri temizle
	config.RedisClient.Del(ctx, "user_match:"+userId)
	config.RedisClient.Del(ctx, "user_match:"+targetUserId)
	config.RedisClient.Del(ctx, "accept:"+roomID+":"+userId)
	config.RedisClient.Del(ctx, "accept:"+roomID+":"+targetUserId)
	config.RedisClient.Del(ctx, "chatroom:"+roomID)

	log.Printf("🛑 Eşleşme reddedildi: %s vs %s", userId, targetUserId)
	return nil
}

// GetMatchPoolSize — Belirli bir filmin havuzundaki kişi sayısını döner
func GetMatchPoolSize(tmdbID int) int {
	if candidatePool != nil {
		return candidatePool.GetPoolSize(tmdbID)
	}
	return 0
}
