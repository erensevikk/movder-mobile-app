package controllers

import (
	"context"
	"encoding/json"
	"log"
	"movder-backend/config"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// ─── WebSocket Yapılandırması ────────────────────────────────
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Geliştirme aşamasında tüm origin'lere izin ver
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

// HandleWebSocket — WebSocket bağlantı handler'ı
// /ws/chat/:roomId?token=xxx şeklinde çağrılır
func HandleWebSocket() gin.HandlerFunc {
	return func(c *gin.Context) {
		roomID := c.Param("roomId")
		tokenStr := c.Query("token")

		// 1. JWT doğrulaması
		if tokenStr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token gerekli"})
			return
		}

		userId, username, err := validateWSToken(tokenStr)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz token"})
			return
		}

		// 2. Oda var mı kontrol et (Redis'te)
		ctx := context.Background()
		_, err = config.RedisClient.Get(ctx, "chatroom:"+roomID).Result()
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Sohbet odası bulunamadı"})
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
				break // Bağlantı koptu
			}

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

			// Status belirle: Karşı taraf websocket ile bağlıysa delivered, değilse sent.
			// read statüsü yalnızca read_receipt ile verilmelidir.
			msgStatus := "sent"
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

			receiverConnCount := 0
			if receiverId != "" {
				receiverConnCount = len(roomUsers[receiverId])
			}
			chatMu.RUnlock()

			// delivered: alıcıya ait en az bir aktif bağlantı varsa
			// read: sadece read_receipt ile set edilir
			if receiverConnCount > 0 {
				msgStatus = "delivered"
			} else {
				msgStatus = "sent"
			}
			log.Printf("📨 status-eval room=%s sender=%s receiver=%s receiverConns=%d status=%s", roomID, userId, receiverId, receiverConnCount, msgStatus)

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

func joinRoom(roomID, userId string, conn *websocket.Conn) {
	chatMu.Lock()
	defer chatMu.Unlock()

	if chatRooms[roomID] == nil {
		chatRooms[roomID] = make(map[string]map[*websocket.Conn]bool)
	}
	if chatRooms[roomID][userId] == nil {
		chatRooms[roomID][userId] = make(map[*websocket.Conn]bool)
	}
	chatRooms[roomID][userId][conn] = true
	log.Printf("👤 %s odaya katıldı: %s (userConnCount=%d roomUserCount=%d)", userId, roomID, len(chatRooms[roomID][userId]), len(chatRooms[roomID]))
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
		if err := conn.WriteMessage(websocket.TextMessage, msgJSON); err != nil {
			log.Printf("⚠️ broadcast write failed room=%s type=%s err=%v", roomID, msg.Type, err)
		}
	}
}

// saveChatMessage — Mesajı MongoDB'ye asenkron kaydeder
func saveChatMessage(msg ChatMessage) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		collection := config.GetCollection(config.DB, "messages")
		_, err := collection.InsertOne(ctx, msg)
		if err != nil {
			log.Println("Mesaj kaydedilemedi:", err)
		}
	}()
}

// markMessagesAsRead — Bir odadaki tüm okunmamış mesajları 'read' statüsüne çeker
func markMessagesAsRead(roomID string, userId string) {
	go func() {
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
	}()
}

// GetChatRooms — Kullanıcının katıldığı sohbet odalarını listeler (son mesaj dahil)
// GET /api/chat/rooms
func GetChatRooms() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

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
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Sohbet odaları alınamadı"})
			return
		}
		defer cursor.Close(ctx)

		type RoomDoc struct {
			RoomID    string `bson:"roomId"`
			User1ID   string `bson:"user1Id"`
			User2ID   string `bson:"user2Id"`
			MovieName string `bson:"movieName"`
			PosterURL string `bson:"posterUrl"`
		}

		var result []map[string]interface{}

		var roomCount int
		var emptyAvatarCount int
		var emptyMovieCount int
		for cursor.Next(ctx) {
			var room RoomDoc
			if err := cursor.Decode(&room); err != nil {
				log.Printf("🔎 GetChatRooms decode room failed userId=%s err=%v", userId, err)
				continue
			}
			roomCount++

			// Karşı tarafın ID'si
			otherUserId := room.User2ID
			if room.User2ID == userId {
				otherUserId = room.User1ID
			}

			// Karşı kullanıcı bilgilerini çek
			otherObjID, objErr := primitive.ObjectIDFromHex(otherUserId)
			var otherUser struct {
				Username  string `bson:"username"`
				AvatarURL string `bson:"avatar_url"`
			}
			if objErr != nil {
				log.Printf("🔎 GetChatRooms invalid otherUserId roomId=%s userId=%s otherUserId=%q err=%v", room.RoomID, userId, otherUserId, objErr)
			} else {
				if err := usersCol.FindOne(ctx, bson.M{"_id": otherObjID}).Decode(&otherUser); err != nil {
					log.Printf("🔎 GetChatRooms users lookup failed roomId=%s userId=%s otherUserId=%s err=%v", room.RoomID, userId, otherUserId, err)
				}
			}

			// Bu odanın son mesajını çek
			var lastMsg struct {
				Content   string `bson:"content"`
				Timestamp int64  `bson:"timestamp"`
				SenderID  string `bson:"senderId"`
				Status    string `bson:"status"`
			}
			opts := map[string]interface{}{}
			_ = opts
			msgCursor, msgFindErr := msgsCol.Find(ctx,
				bson.M{"roomId": room.RoomID, "type": "message"},
			)
			if msgFindErr != nil {
				log.Printf("🔎 GetChatRooms message lookup failed roomId=%s err=%v", room.RoomID, msgFindErr)
			}
			var lastMsgFound bool
			var latestTimestamp int64
			for msgCursor != nil && msgCursor.Next(ctx) {
				var m struct {
					Content   string `bson:"content"`
					Timestamp int64  `bson:"timestamp"`
					SenderID  string `bson:"senderId"`
					Status    string `bson:"status"`
				}
				if err := msgCursor.Decode(&m); err != nil {
					continue
				}
				if m.Timestamp > latestTimestamp {
					latestTimestamp = m.Timestamp
					lastMsg = m
					lastMsgFound = true
				}
			}
			if msgCursor != nil {
				msgCursor.Close(ctx)
			}

			// Okunmamış mesaj sayısı
			unreadCount, _ := msgsCol.CountDocuments(ctx, bson.M{
				"roomId":   room.RoomID,
				"senderId": bson.M{"$ne": userId},
				"status":   bson.M{"$in": []string{"sent", "delivered"}},
			})

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
			}

			if strings.TrimSpace(otherUser.AvatarURL) == "" {
				emptyAvatarCount++
			}
			if strings.TrimSpace(room.MovieName) == "" {
				emptyMovieCount++
			}
			log.Printf("🔎 GetChatRooms roomId=%s targetUserId=%s username=%q avatarEmpty=%t movieEmpty=%t posterEmpty=%t unread=%d", room.RoomID, otherUserId, otherUser.Username, strings.TrimSpace(otherUser.AvatarURL) == "", strings.TrimSpace(room.MovieName) == "", strings.TrimSpace(room.PosterURL) == "", unreadCount)

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
		userId := c.GetString("userId")
		roomID := c.Param("roomId")

		// Kullanıcının bu odada yetkisi var mı?
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

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
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu odaya erişim yetkiniz yok"})
			return
		}

		msgsCol := config.GetCollection(config.DB, "messages")
		cursor, err := msgsCol.Find(ctx,
			bson.M{"roomId": roomID, "type": "message"},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Mesajlar alınamadı"})
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
