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

// Aktif sohbet odaları: roomID → bağlı kullanıcılar
var chatRooms = make(map[string]map[string]*websocket.Conn)
var chatMu sync.RWMutex

// ChatMessage — Sohbet mesajı yapısı
type ChatMessage struct {
	ID        primitive.ObjectID `json:"_id,omitempty" bson:"_id,omitempty"`
	Type      string             `json:"type" bson:"type"` // "message", "join", "leave", "read_receipt"
	UserID    string             `json:"userId" bson:"userId"`
	Username  string             `json:"username" bson:"username"`
	Content   string             `json:"content" bson:"content"`
	Timestamp int64              `json:"timestamp" bson:"timestamp"`
	RoomID    string             `json:"roomId" bson:"roomId"`
	Status    string             `json:"status" bson:"status"` // "sent", "delivered", "read"
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
		defer leaveRoom(roomID, userId)

		// Katılım mesajı gönder
		broadcastToRoom(roomID, ChatMessage{
			Type:      "join",
			UserID:    userId,
			Username:  username,
			Content:   username + " sohbete katıldı",
			Timestamp: time.Now().Unix(),
			RoomID:    roomID,
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
					UserID:    userId,
					Timestamp: time.Now().Unix(),
					RoomID:    roomID,
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

			// Status belirle: Karşı taraf odada mı? Odadaysa read, yoksa delivered/sent
			msgStatus := "sent"
			chatMu.RLock()
			roomUsers := chatRooms[roomID]
			chatMu.RUnlock()

			// Odada iki kişi varsa okunmuştur
			if len(roomUsers) > 1 {
				msgStatus = "read"
			} else {
				// Karşı tarafı odadan çıkarıp, online mı diye Redis'e de bakabiliriz, ama şimdilik "sent" yapalım
				// (Veya "delivered" yapabilirdik redis online check ile)
				msgStatus = "sent"
			}

			chatMsg := ChatMessage{
				ID:        primitive.NewObjectID(),
				Type:      "message",
				UserID:    userId,
				Username:  username,
				Content:   content,
				Timestamp: time.Now().Unix(),
				RoomID:    roomID,
				Status:    msgStatus,
			}

			broadcastToRoom(roomID, chatMsg)
			saveChatMessage(chatMsg) // Asenkron MongoDB'ye kaydet
		}

		// Ayrılma mesajı
		broadcastToRoom(roomID, ChatMessage{
			Type:      "leave",
			UserID:    userId,
			Username:  username,
			Content:   username + " sohbetten ayrıldı",
			Timestamp: time.Now().Unix(),
			RoomID:    roomID,
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
		chatRooms[roomID] = make(map[string]*websocket.Conn)
	}
	chatRooms[roomID][userId] = conn
	log.Printf("👤 %s odaya katıldı: %s", userId, roomID)
}

func leaveRoom(roomID, userId string) {
	chatMu.Lock()
	defer chatMu.Unlock()

	if room, ok := chatRooms[roomID]; ok {
		delete(room, userId)
		if len(room) == 0 {
			delete(chatRooms, roomID)
		}
	}
	log.Printf("👤 %s odadan ayrıldı: %s", userId, roomID)
}

func broadcastToRoom(roomID string, msg ChatMessage) {
	chatMu.RLock()
	defer chatMu.RUnlock()

	room, ok := chatRooms[roomID]
	if !ok {
		return
	}

	msgJSON, _ := json.Marshal(msg)
	for _, conn := range room {
		conn.WriteMessage(websocket.TextMessage, msgJSON)
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
		// Benim dışımda gönderilen (userId'si farklı olan) ve odaya ait mesajların statusünü read yap
		filter := bson.M{
			"roomId": roomID,
			"userId": bson.M{"$ne": userId},
			"status": bson.M{"$in": []string{"sent", "delivered"}},
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
