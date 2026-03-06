package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"movder-backend/config"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ─── WebSocket Yapılandırması ────────────────────────────────

// Rate limiter yapısı: IP -> sayac + son istek zamanı
type rateLimiter struct {
	count    int
	lastSeen time.Time
}

var (
	rateLimitMap = make(map[string]*rateLimiter)
	rateLimitMu  sync.Mutex

	// Rate limiting ayarları
	wsRateLimitMaxConns = 100              // IP başına max eşzamanlı bağlantı
	wsRateLimitWindow   = 60 * time.Second // Pencere süresi
	wsRateLimitPurge    = 5 * time.Minute  // Temizleme aralığı
)

// cleanupRateLimitMap Eski rate limit entries temizler
func cleanupRateLimitMap() {
	ticker := time.NewTicker(wsRateLimitPurge)
	for range ticker.C {
		rateLimitMu.Lock()
		now := time.Now()
		for ip, rl := range rateLimitMap {
			if now.Sub(rl.lastSeen) > wsRateLimitPurge {
				delete(rateLimitMap, ip)
			}
		}
		rateLimitMu.Unlock()
	}
}

// isRateLimited IP'nin rate limit aşıp aşmadığını kontrol eder
func isRateLimited(ip string) bool {
	rateLimitMu.Lock()
	defer rateLimitMu.Unlock()

	rl, exists := rateLimitMap[ip]
	now := time.Now()

	if !exists || now.Sub(rl.lastSeen) > wsRateLimitWindow {
		// Yeni veya süresi dolmuş - resetle
		rateLimitMap[ip] = &rateLimiter{count: 1, lastSeen: now}
		return false
	}

	if rl.count >= wsRateLimitMaxConns {
		return true
	}

	rl.count++
	rl.lastSeen = now
	return false
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")

		// Development: tüm origin'lere izin ver
		if config.GetAllowedOrigins() == "*" {
			return true
		}

		// Production: sadece whitelist'teki origin'lere izin ver
		if origin != "" && !config.IsOriginAllowed(origin) {
			log.Printf("⚠️  WebSocket origin reddedildi: %s", origin)
			return false
		}

		return true
	},
}

// Aktif sohbet odaları: roomID -> userID -> user'a ait aktif websocket bağlantıları
var chatRooms = make(map[string]map[string]map[*websocket.Conn]bool)
var chatMu sync.RWMutex

// ChatMessage — Sohbet mesajı yapısı
type ChatMessage struct {
	ID         primitive.ObjectID `json:"_id,omitempty" bson:"_id,omitempty"`
	Type       string             `json:"type" bson:"type"` // "message", "join", "leave", "read_receipt"
	RoomID     string             `json:"roomId" bson:"roomId"`
	SenderID   string             `json:"senderId" bson:"senderId"`
	ReceiverID string             `json:"receiverId" bson:"receiverId"`
	SenderName string             `json:"senderName" bson:"senderName"`
	Content    string             `json:"content" bson:"content"`
	Timestamp  int64              `json:"timestamp" bson:"timestamp"`
	Status     string             `json:"status" bson:"status"` // "sent", "delivered", "read"
}

// init Rate limiting cleanup goroutine'ı başlat
func init() {
	go cleanupRateLimitMap()
}

// WebSocket için temel limit ve timeout ayarları
const (
	wsMaxMessageSize         = 64 * 1024        // 64KB
	wsReadTimeout            = 60 * time.Second // Pong gelmezse 60 saniye içinde bağlantıyı kapat
	wsWriteTimeout           = 10 * time.Second // Yavaş client için yazma süresi limiti
	wsMaxConnsPerUserPerRoom = 5                // Aynı odada bir kullanıcı için en fazla eşzamanlı bağlantı
)

// HandleWebSocket — WebSocket bağlantı handler'ı
// /ws/chat/:roomId?token=xxx şeklinde çağrılır
func HandleWebSocket() gin.HandlerFunc {
	return func(c *gin.Context) {
		roomID := c.Param("roomId")
		tokenStr := c.Query("token")

		// 0. Rate limiting kontrolü (IP bazlı)
		clientIP := c.ClientIP()
		if isRateLimited(clientIP) {
			log.Printf("⚠️  WebSocket rate limit aşıldı: %s", clientIP)
			errorResponse(c, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED", "Çok fazla bağlantı isteği", nil)
			return
		}

		// 1. JWT doğrulaması
		if tokenStr == "" {
			errorResponse(c, http.StatusUnauthorized, "MISSING_TOKEN", "Token gerekli", nil)
			return
		}

		userId, username, err := validateWSToken(tokenStr)
		if err != nil {
			errorResponse(c, http.StatusUnauthorized, "INVALID_TOKEN", "Geçersiz token", nil)
			return
		}

		// 2. Oda var mı ve kullanıcı bu odaya dahil mi kontrol et (MongoDB)
		// Redis "chatroom:*" anahtarı geçici TTL ile silinebildiği için
		// kalıcı kaynak olan chatrooms koleksiyonunu esas alıyoruz.
		ctx := context.Background()
		roomsCol := config.GetCollection(config.DB, "chatrooms")
		err = roomsCol.FindOne(ctx, bson.M{
			"roomId": roomID,
			"$or": bson.A{
				bson.M{"user1Id": userId},
				bson.M{"user2Id": userId},
			},
		}).Err()
		if err != nil {
			errorResponse(c, http.StatusNotFound, "CHAT_ROOM_NOT_FOUND", "Sohbet odası bulunamadı", nil)
			return
		}

		// 3. WebSocket'e yükselt
		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			log.Println("WebSocket yükseltme hatası:", err)
			return
		}
		defer conn.Close()

		// 4. Odaya katıl
		joinRoom(roomID, userId, conn)
		defer leaveRoom(roomID, userId, conn)

		// Katılım mesajı gönder
		broadcastToRoom(roomID, ChatMessage{
			Type:       "join",
			RoomID:     roomID,
			SenderID:   userId,
			SenderName: username,
			Content:    username + " sohbete katıldı",
			Timestamp:  time.Now().Unix(),
		})

		// 5. Mesajları dinle
		for {
			_, msg, err := conn.ReadMessage()
			if err != nil {
				break // Bağlantı koptu veya timeout oluştu
			}
			// Her başarılı okuma sonrası read deadline'ı yenile
			_ = conn.SetReadDeadline(time.Now().Add(wsReadTimeout))

			// Gelen mesaj yapısını parse et
			var incoming struct {
				Type    string `json:"type"`
				Content string `json:"content"`
			}

			// Eğer sadece düz metin geldiyse varsayılan type'ı message kabul et
			if err := json.Unmarshal(msg, &incoming); err != nil {
				incoming.Type = "message"
				incoming.Content = string(msg)
			}

			if incoming.Type == "read_receipt" {
				// Kullanıcı mesajları okuduğunu bildirdi, MongoDB'de "read" olarak işaretle ve odadakilere haber ver
				markMessagesAsRead(roomID, userId)
				broadcastToRoom(roomID, ChatMessage{
					Type:      "read_receipt",
					RoomID:    roomID,
					SenderID:  userId,
					Timestamp: time.Now().Unix(),
				})
				continue
			}

			// Mesaj boyutu kontrolü (max 1000 karakter)
			content := incoming.Content
			if len(content) > 1000 {
				content = content[:1000]
			}
			content = strings.TrimSpace(content)
			if content == "" {
				continue
			}

			// Eşleşme iptal edilmişse mesaj göndermeyi engelle
			checkCtx, checkCancel := context.WithTimeout(context.Background(), 3*time.Second)
			var roomStatus struct {
				Status string `bson:"status"`
			}
			if err := config.GetCollection(config.DB, "chatrooms").FindOne(checkCtx, bson.M{"roomId": roomID}).Decode(&roomStatus); err == nil && roomStatus.Status == "unmatched" {
				checkCancel()
				log.Printf("🚫 message blocked — room %s is unmatched, sender=%s", roomID, userId)
				continue
			}
			checkCancel()

			// Mesaj sunucuya ulaştıysa 'delivered' olarak kaydedilir.
			// 'read' statüsü yalnızca read_receipt ile verilir.
			msgStatus := "delivered"
			chatMu.RLock()
			roomUsers := chatRooms[roomID]

			// Odadaki diğer kullanıcıyı receiver olarak belirle
			receiverId := ""
			for uid := range roomUsers {
				if uid != userId {
					receiverId = uid
					break
				}
			}
			chatMu.RUnlock()

			log.Printf("📨 status-eval room=%s sender=%s receiver=%s status=%s", roomID, userId, receiverId, msgStatus)

			// NOT: Eğer karşı taraf odada yoksa, receiverId'yi chatrooms koleksiyonundan da çekebiliriz (fallback)
			// Ancak şema sadece "messages" olduğu için, aslında eşleşmeden dönen targetUserId'yi client bize ws ile "receiverId" olarak iletebilir.
			// Şimdilik WebSocket içerisindeki `incoming` mesajına bunu eklemediğimizden ve client şu an bunu yollamadığından
			// ReceiverID eksikliğini en basit `incoming` üzerinden halletmek gerekir. (Aşağıda ele alınıyor)

			chatMsg := ChatMessage{
				ID:         primitive.NewObjectID(),
				Type:       "message",
				RoomID:     roomID,
				SenderID:   userId,
				ReceiverID: receiverId, // Odadaki kişi, eğer yoksa boş kalır (bunu çözmeliyiz)
				SenderName: username,
				Content:    content,
				Timestamp:  time.Now().Unix(),
				Status:     msgStatus,
			}

			broadcastToRoom(roomID, chatMsg)
			saveChatMessage(chatMsg) // Asenkron MongoDB'ye kaydet
		}

		// Ayrılma mesajı
		broadcastToRoom(roomID, ChatMessage{
			Type:       "leave",
			RoomID:     roomID,
			SenderID:   userId,
			SenderName: username,
			Content:    username + " sohbetten ayrıldı",
			Timestamp:  time.Now().Unix(),
		})
	}
}

// ─── WebSocket Yardımcı Fonksiyonları ──────────────────────

func validateWSToken(tokenStr string) (string, string, error) {
	jwtSecret := config.GetEnv("JWT_SECRET", "default_secret")

	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(jwtSecret), nil
	})

	if err != nil || !token.Valid {
		return "", "", err
	}

	claims := token.Claims.(jwt.MapClaims)
	userId, _ := claims["userId"].(string)
	username, _ := claims["username"].(string)

	return userId, username, nil
}

func joinRoom(roomID, userId string, conn *websocket.Conn) bool {
	chatMu.Lock()
	defer chatMu.Unlock()

	if chatRooms[roomID] == nil {
		chatRooms[roomID] = make(map[string]map[*websocket.Conn]bool)
	}
	if chatRooms[roomID][userId] == nil {
		chatRooms[roomID][userId] = make(map[*websocket.Conn]bool)
	}

	// Aynı kullanıcı için bağlantı limiti kontrolü
	if len(chatRooms[roomID][userId]) >= wsMaxConnsPerUserPerRoom {
		log.Printf("⚠️ WS per-user connection limit reached room=%s userId=%s", roomID, userId)
		return false
	}

	chatRooms[roomID][userId][conn] = true
	log.Printf("👤 %s odaya katıldı: %s (userConnCount=%d roomUserCount=%d)", userId, roomID, len(chatRooms[roomID][userId]), len(chatRooms[roomID]))
	return true
}

func leaveRoom(roomID, userId string, conn *websocket.Conn) {
	chatMu.Lock()
	defer chatMu.Unlock()

	if room, ok := chatRooms[roomID]; ok {
		if userConns, ok := room[userId]; ok {
			delete(userConns, conn)
			if len(userConns) == 0 {
				delete(room, userId)
			}
		}
		if len(room) == 0 {
			delete(chatRooms, roomID)
		}
	}

	userConnCount := 0
	roomUserCount := 0
	if room, ok := chatRooms[roomID]; ok {
		roomUserCount = len(room)
		if userConns, ok := room[userId]; ok {
			userConnCount = len(userConns)
		}
	}
	log.Printf("👤 %s odadan ayrıldı: %s (userConnCount=%d roomUserCount=%d)", userId, roomID, userConnCount, roomUserCount)
}

func broadcastToRoom(roomID string, msg ChatMessage) {
	chatMu.RLock()
	room, ok := chatRooms[roomID]
	if !ok {
		chatMu.RUnlock()
		return
	}

	// Kilidi uzun süre tutmamak için bağlantı snapshot'u al
	conns := make([]*websocket.Conn, 0)
	for _, userConns := range room {
		for conn := range userConns {
			conns = append(conns, conn)
		}
	}
	chatMu.RUnlock()

	msgJSON, _ := json.Marshal(msg)
	for _, conn := range conns {
		// Yavaş client'lar için write timeout uygula
		_ = conn.SetWriteDeadline(time.Now().Add(wsWriteTimeout))
		if err := conn.WriteMessage(websocket.TextMessage, msgJSON); err != nil {
			log.Printf("⚠️ broadcast write failed room=%s type=%s err=%v", roomID, msg.Type, err)
			_ = conn.Close()
		}
	}
}

// saveChatMessage — Mesajı MongoDB'ye worker pool üzerinden kaydeder
// Backpressure: buffer dolunca task reddedilir, memory pressure önelnir
func saveChatMessage(msg ChatMessage) {
	if config.MessagePersistencePool == nil {
		// Fallback: pool yoksa doğrudan kaydet (init henüz tamamlanmamış olabilir)
		saveChatMessageDirect(msg)
		return
	}

	success := config.MessagePersistencePool.Submit(
		func(payload interface{}) {
			m := payload.(ChatMessage)
			saveChatMessageDirect(m)
		},
		msg,
	)
	if !success {
		// Backpressure: mesaj kaydedilemedi, logla
		log.Printf("⚠️  Mesaj kaydedilemedi (pool dolu): %s", msg.RoomID)
	}
}

// saveChatMessageDirect — Mesajı MongoDB'ye asenkron kaydeder (direct implementation)
func saveChatMessageDirect(msg ChatMessage) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	collection := config.GetCollection(config.DB, "messages")
	_, err := collection.InsertOne(ctx, msg)
	if err != nil {
		log.Println("Mesaj kaydedilemedi:", err)
	}
}

// markMessagesAsRead — Bir odadaki tüm okunmamış mesajları 'read' statüsüne çeker
// Worker pool kullanarak backpressure uygula
func markMessagesAsRead(roomID string, userId string) {
	if config.ReadReceiptPool == nil {
		markMessagesAsReadDirect(roomID, userId)
		return
	}

	success := config.ReadReceiptPool.Submit(
		func(payload interface{}) {
			params := payload.(map[string]string)
			markMessagesAsReadDirect(params["roomID"], params["userId"])
		},
		map[string]string{"roomID": roomID, "userId": userId},
	)
	if !success {
		log.Printf("⚠️  Read receipt güncellenemedi (pool dolu): %s", roomID)
	}
}

// markMessagesAsReadDirect — Bir odadaki tüm okunmamış mesajları 'read' statüsüne çeker (direct)
func markMessagesAsReadDirect(roomID string, userId string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	collection := config.GetCollection(config.DB, "messages")
	// Benim dışımda gönderilen (senderId'si farklı olan) ve odaya ait mesajların statusünü read yap
	filter := bson.M{
		"roomId":   roomID,
		"senderId": bson.M{"$ne": userId},
		"status":   bson.M{"$in": []string{"sent", "delivered"}},
	}
	update := bson.M{
		"$set": bson.M{"status": "read"},
	}

	_, err := collection.UpdateMany(ctx, filter, update)
	if err != nil {
		log.Println("Mesajlar read olarak işaretlenemedi:", err)
	}
}

// findChatRoomIDBetweenUsers - iki kullanıcı arasındaki mevcut sohbet odasını bulur.
// Oda yoksa boş string döner.
func findChatRoomIDBetweenUsers(ctx context.Context, userA, userB string) (string, error) {
	roomsCol := config.GetCollection(config.DB, "chatrooms")
	var room struct {
		RoomID string `bson:"roomId"`
	}

	err := roomsCol.FindOne(ctx, bson.M{
		"$or": bson.A{
			bson.M{"user1Id": userA, "user2Id": userB},
			bson.M{"user1Id": userB, "user2Id": userA},
		},
	}).Decode(&room)
	if err != nil {
		return "", err
	}

	return room.RoomID, nil
}

// GetChatRooms — Kullanıcının katıldığı sohbet odalarını listeler (son mesaj dahil)
// GET /api/chat/rooms
func GetChatRooms() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		roomsCol := config.GetCollection(config.DB, "chatrooms")
		msgsCol := config.GetCollection(config.DB, "messages")
		usersCol := config.GetCollection(config.DB, "users")

		// Kullanıcının dahil olduğu tüm odaları çek
		filter := bson.M{
			"$or": bson.A{
				bson.M{"user1Id": userId},
				bson.M{"user2Id": userId},
			},
		}

		cursor, err := roomsCol.Find(ctx, filter)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "CHAT_ROOMS_QUERY_FAILED", "Sohbet odaları alınamadı", err.Error())
			return
		}
		defer cursor.Close(ctx)

		type RoomDoc struct {
			RoomID      string `bson:"roomId"`
			User1ID     string `bson:"user1Id"`
			User2ID     string `bson:"user2Id"`
			MovieName   string `bson:"movieName"`
			PosterURL   string `bson:"posterUrl"`
			Status      string `bson:"status"`
			UnmatchedBy string `bson:"unmatchedBy"`
		}

		// Tüm odaları hafızaya al (N adet room dokümanı)
		var rooms []RoomDoc
		if err := cursor.All(ctx, &rooms); err != nil {
			log.Printf("🔎 GetChatRooms rooms cursor.All failed userId=%s err=%v", userId, err)
			errorResponse(c, http.StatusInternalServerError, "CHAT_ROOMS_READ_FAILED", "Sohbet odaları alınamadı", err.Error())
			return
		}

		if len(rooms) == 0 {
			c.JSON(http.StatusOK, []map[string]interface{}{})
			return
		}

		// Karşı kullanıcıları tek seferde çekmek için userId set'i
		userIDSet := make(map[string]struct{})
		for _, room := range rooms {
			otherUserId := room.User2ID
			if room.User2ID == userId {
				otherUserId = room.User1ID
			}
			if strings.TrimSpace(otherUserId) == "" {
				continue
			}
			userIDSet[otherUserId] = struct{}{}
		}

		// Hex -> ObjectID map ve toplu kullanıcı sorgusu
		hexToObjID := make(map[string]primitive.ObjectID)
		var userObjIDs []primitive.ObjectID
		for hexID := range userIDSet {
			objID, err := primitive.ObjectIDFromHex(hexID)
			if err != nil {
				log.Printf("🔎 GetChatRooms invalid otherUserId for preload userId=%s otherUserId=%q err=%v", userId, hexID, err)
				continue
			}
			hexToObjID[hexID] = objID
			userObjIDs = append(userObjIDs, objID)
		}

		// Kullanıcıları tek seferde çek ve map'e al
		type userBrief struct {
			Username  string `bson:"username"`
			AvatarURL string `bson:"avatar_url"`
		}
		userMap := make(map[primitive.ObjectID]userBrief)
		if len(userObjIDs) > 0 {
			userCursor, err := usersCol.Find(ctx, bson.M{"_id": bson.M{"$in": userObjIDs}})
			if err != nil {
				log.Printf("🔎 GetChatRooms users bulk lookup failed userId=%s err=%v", userId, err)
			} else {
				for userCursor.Next(ctx) {
					var u struct {
						ID        primitive.ObjectID `bson:"_id"`
						Username  string             `bson:"username"`
						AvatarURL string             `bson:"avatar_url"`
					}
					if err := userCursor.Decode(&u); err != nil {
						continue
					}
					userMap[u.ID] = userBrief{Username: u.Username, AvatarURL: u.AvatarURL}
				}
				userCursor.Close(ctx)
			}
		}

		var result []map[string]interface{}
		var roomCount int
		var emptyAvatarCount int
		var emptyMovieCount int

		for _, room := range rooms {
			// Kullanıcı bu odayı gizlediyse: hide timestamp'i al
			hiddenKey := "chat:hidden:" + userId
			var hideTS int64
			if tsStr, err := config.RedisClient.HGet(ctx, hiddenKey, room.RoomID).Result(); err == nil {
				hideTS, _ = strconv.ParseInt(tsStr, 10, 64)
			}
			roomCount++

			// Karşı tarafın ID'si
			otherUserId := room.User2ID
			if room.User2ID == userId {
				otherUserId = room.User1ID
			}

			// Karşı kullanıcı bilgilerini bulk map'ten çek
			var otherUser userBrief
			if objID, ok := hexToObjID[otherUserId]; ok {
				if u, found := userMap[objID]; found {
					otherUser = u
				} else {
					log.Printf("🔎 GetChatRooms user not found in userMap roomId=%s userId=%s targetUserId=%s", room.RoomID, userId, otherUserId)
				}
			} else if otherUserId != "" {
				// Hex parse edilemediyse yine logla (preload aşamasında da loglanmış olabilir)
				log.Printf("🔎 GetChatRooms missing hexToObjID mapping roomId=%s userId=%s targetUserId=%s", room.RoomID, userId, otherUserId)
			}

			// Bu odanın son mesajını çek: timestamp DESC, limit 1
			var lastMsg struct {
				Content   string `bson:"content"`
				Timestamp int64  `bson:"timestamp"`
				SenderID  string `bson:"senderId"`
				Status    string `bson:"status"`
			}
			msgFilter := bson.M{"roomId": room.RoomID, "type": "message"}
			if hideTS > 0 {
				msgFilter["timestamp"] = bson.M{"$gt": hideTS}
			}
			lastMsgFound := false
			findOpts := options.FindOne().SetSort(bson.D{{Key: "timestamp", Value: -1}})
			if err := msgsCol.FindOne(ctx, msgFilter, findOpts).Decode(&lastMsg); err == nil {
				lastMsgFound = true
			}

			// Gizlenmiş oda ama sonrasında mesaj yoksa listeye ekleme
			if hideTS > 0 && !lastMsgFound {
				continue
			}

			// Okunmamış mesaj sayısı (hide timestamp filtresiyle)
			unreadFilter := bson.M{
				"roomId":   room.RoomID,
				"senderId": bson.M{"$ne": userId},
				"status":   bson.M{"$in": []string{"sent", "delivered"}},
			}
			if hideTS > 0 {
				unreadFilter["timestamp"] = bson.M{"$gt": hideTS}
			}
			unreadCount, _ := msgsCol.CountDocuments(ctx, unreadFilter)

			entry := map[string]interface{}{
				"roomId":        room.RoomID,
				"targetUserId":  otherUserId,
				"username":      otherUser.Username,
				"avatarSeed":    otherUserId,
				"avatarUrl":     otherUser.AvatarURL,
				"movieTitle":    room.MovieName,
				"moviePoster":   room.PosterURL,
				"unreadCount":   unreadCount,
				"lastMessage":   "",
				"lastTimestamp": int64(0),
				"status":        room.Status,
				"unmatchedBy":   room.UnmatchedBy,
			}

			if strings.TrimSpace(otherUser.AvatarURL) == "" {
				emptyAvatarCount++
			}
			if strings.TrimSpace(room.MovieName) == "" {
				emptyMovieCount++
			}
			log.Printf("🔎 GetChatRooms roomId=%s targetUserId=%s status=%q username=%q avatarEmpty=%t movieEmpty=%t posterEmpty=%t unread=%d", room.RoomID, otherUserId, room.Status, otherUser.Username, strings.TrimSpace(otherUser.AvatarURL) == "", strings.TrimSpace(room.MovieName) == "", strings.TrimSpace(room.PosterURL) == "", unreadCount)

			if lastMsgFound {
				entry["lastMessage"] = lastMsg.Content
				entry["lastTimestamp"] = lastMsg.Timestamp
			}

			result = append(result, entry)
		}
		log.Printf("🔎 GetChatRooms summary userId=%s rooms=%d emptyAvatar=%d emptyMovie=%d", userId, roomCount, emptyAvatarCount, emptyMovieCount)

		if result == nil {
			result = []map[string]interface{}{}
		}

		c.JSON(http.StatusOK, result)
	}
}

// GetChatMessages — Bir sohbet odasının mesaj geçmişini döner
// GET /api/chat/rooms/:roomId/messages?limit=50
func GetChatMessages() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}
		roomID := c.Param("roomId")
		if strings.TrimSpace(roomID) == "" {
			// roomId path param eksik veya boş
			errorResponse(c, http.StatusBadRequest, "INVALID_ROOM_ID", "Geçerli bir roomId gerekli", nil)
			return
		}

		// Kullanıcının bu odada yetkisi var mı?
		roomsCol := config.GetCollection(config.DB, "chatrooms")
		var room struct {
			User1ID string `bson:"user1Id"`
			User2ID string `bson:"user2Id"`
		}
		err := roomsCol.FindOne(ctx, bson.M{
			"roomId": roomID,
			"$or": bson.A{
				bson.M{"user1Id": userId},
				bson.M{"user2Id": userId},
			},
		}).Decode(&room)
		if err != nil {
			// Odaya erişim yetkisi yok
			errorResponse(c, http.StatusForbidden, "FORBIDDEN", "Bu odaya erişim yetkiniz yok", nil)
			return
		}

		msgsCol := config.GetCollection(config.DB, "messages")
		// Kullanıcı bu odayı gizlediyse, sadece gizleme sonrası mesajları göster
		msgFilter := bson.M{"roomId": roomID, "type": "message"}
		hiddenKey := "chat:hidden:" + userId
		if tsStr, err := config.RedisClient.HGet(ctx, hiddenKey, roomID).Result(); err == nil {
			if hideTS, parseErr := strconv.ParseInt(tsStr, 10, 64); parseErr == nil && hideTS > 0 {
				msgFilter["timestamp"] = bson.M{"$gt": hideTS}
			}
		}
		cursor, err := msgsCol.Find(ctx, msgFilter)
		if err != nil {
			// Mesajlar çekilirken hata oluştu
			errorResponse(c, http.StatusInternalServerError, "MESSAGES_QUERY_FAILED", "Mesajlar alınamadı", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var messages []map[string]interface{}
		for cursor.Next(ctx) {
			var msg ChatMessage
			if err := cursor.Decode(&msg); err != nil {
				continue
			}
			messages = append(messages, map[string]interface{}{
				"_id":        msg.ID.Hex(),
				"roomId":     msg.RoomID,
				"senderId":   msg.SenderID,
				"receiverId": msg.ReceiverID,
				"senderName": msg.SenderName,
				"content":    msg.Content,
				"timestamp":  msg.Timestamp,
				"status":     msg.Status,
				"isMe":       msg.SenderID == userId,
			})
		}

		if messages == nil {
			messages = []map[string]interface{}{}
		}

		c.JSON(http.StatusOK, messages)
	}
}

// HideChatRoom - bir sohbeti sadece isteği atan kullanıcı için gizler.
// DELETE /api/chat/rooms/:roomId
func HideChatRoom() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		roomID := c.Param("roomId")
		log.Printf("🧪 CHAT-DELETE-DBG start userId=%s roomId=%s", userId, roomID)
		if roomID == "" {
			log.Printf("🧪 CHAT-DELETE-DBG bad-request userId=%s roomId-empty", userId)
			errorResponse(c, http.StatusBadRequest, "INVALID_ROOM_ID", "roomId gerekli", nil)
			return
		}

		roomsCol := config.GetCollection(config.DB, "chatrooms")
		err := roomsCol.FindOne(ctx, bson.M{
			"roomId": roomID,
			"$or": bson.A{
				bson.M{"user1Id": userId},
				bson.M{"user2Id": userId},
			},
		}).Err()
		if err != nil {
			log.Printf("🧪 CHAT-DELETE-DBG forbidden userId=%s roomId=%s err=%v", userId, roomID, err)
			errorResponse(c, http.StatusForbidden, "FORBIDDEN", "Bu odayı gizleme yetkiniz yok", nil)
			return
		}

		hiddenKey := "chat:hidden:" + userId
		// Eski SET tipli key varsa WRONGTYPE hatasını önlemek için sil
		if keyType, err := config.RedisClient.Type(ctx, hiddenKey).Result(); err == nil && keyType == "set" {
			config.RedisClient.Del(ctx, hiddenKey)
		}
		now := time.Now().Unix()
		if _, err := config.RedisClient.HSet(ctx, hiddenKey, roomID, fmt.Sprintf("%d", now)).Result(); err != nil {
			log.Printf("🧪 CHAT-DELETE-DBG redis-hset-failed userId=%s roomId=%s key=%s err=%v", userId, roomID, hiddenKey, err)
			errorResponse(c, http.StatusInternalServerError, "CHAT_HIDE_FAILED", "Sohbet gizlenemedi", err.Error())
			return
		}
		_ = config.RedisClient.Expire(ctx, hiddenKey, 180*24*time.Hour).Err()
		log.Printf("🧪 CHAT-DELETE-DBG success userId=%s roomId=%s key=%s hideTS=%d", userId, roomID, hiddenKey, now)

		c.JSON(http.StatusOK, gin.H{"message": "Sohbet gizlendi"})
	}
}
