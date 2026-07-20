package controllers

import (
	"encoding/json"
	"log"
	"movder-backend/config"
	"movder-backend/services"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
)

// ────────────────────────────────────────────────────────────────────
// HandleMatchWebSocket — Eşleşme WebSocket endpoint'i
// URL: /ws/match?token=<jwt>
// Tüm eşleşme akışını (arama, kabul, red) WebSocket üzerinden yönetir.
// ────────────────────────────────────────────────────────────────────

var matchWSUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Dev ortamında tüm originlere izin ver
	},
}

// HandleMatchWebSocket WS upgrade handler. JWT doğrulaması query param'dan yapılır.
func HandleMatchWebSocket() gin.HandlerFunc {
	return func(c *gin.Context) {
		// ── 1. JWT Doğrulama (query param'dan) ──
		tokenString := c.Query("token")
		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token gerekli"})
			return
		}

		userID, err := verifyMatchToken(tokenString)
		if err != nil || userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz token"})
			return
		}

		// ── 2. WS Upgrade ──
		conn, err := matchWSUpgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			log.Printf("⚠️ Match WS upgrade hatası: %v", err)
			return
		}

		hub := services.GetMatchHub()
		if hub == nil {
			log.Println("⚠️ MatchHub başlatılmamış!")
			conn.Close()
			return
		}

		mc := &services.MatchConn{
			Hub:    hub,
			Conn:   conn,
			UserID: userID,
			Send:   make(chan []byte, 256),
		}
		// done kanalını MatchConn oluşturduktan sonra init et
		mc.InitDone()

		hub.Register(mc)

		// Her bağlantı için iki goroutine: okuma ve yazma
		go mc.WritePump()
		go matchReadPump(mc, hub)
	}
}

// verifyMatchToken JWT token'ı doğrular ve userId döner.
func verifyMatchToken(tokenString string) (string, error) {
	jwtSecret := config.GetEnv("JWT_SECRET", "default_secret")
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(jwtSecret), nil
	})

	if err != nil || !token.Valid {
		return "", err
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", jwt.ErrTokenInvalidClaims
	}

	userID, _ := claims["userId"].(string)
	return userID, nil
}

// ────────────────────────────────────────────────────────────────────
// matchReadPump — Client'tan gelen mesajları okur ve işler.
// Mesaj tipleri: search_start, accept, reject, cancel
// ────────────────────────────────────────────────────────────────────

func matchReadPump(mc *services.MatchConn, hub *services.MatchHub) {
	defer func() {
		hub.Unregister(mc.UserID)
	}()

	mc.Conn.SetReadLimit(services.MatchMaxMsgSize)
	mc.Conn.SetReadDeadline(time.Now().Add(services.MatchPongWait))
	mc.Conn.SetPongHandler(func(string) error {
		mc.Conn.SetReadDeadline(time.Now().Add(services.MatchPongWait))
		return nil
	})

	for {
		_, message, err := mc.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("⚠️ Match WS okuma hatası (%s): %v", mc.UserID, err)
			}
			break
		}

		var msg map[string]interface{}
		if err := json.Unmarshal(message, &msg); err != nil {
			mc.SendJSON(map[string]interface{}{
				"type":    "error",
				"message": "Geçersiz mesaj formatı",
			})
			continue
		}

		msgType, _ := msg["type"].(string)
		switch msgType {
		case "search_start":
			handleSearchStart(mc, hub, msg)
		case "accept":
			handleAccept(mc, hub, msg)
		case "reject":
			handleReject(mc, hub, msg)
		case "cancel":
			handleCancel(mc, hub, msg)
		default:
			mc.SendJSON(map[string]interface{}{
				"type":    "error",
				"message": "Bilinmeyen mesaj tipi: " + msgType,
			})
		}
	}
}

// ────────────────────────────────────────────────────────────────────
// Mesaj İşleyicileri (Handlers)
// ────────────────────────────────────────────────────────────────────

// handleSearchStart — Eşleşme aramasını başlatır.
// Kullanıcıyı havuza ekler ve anında eşleşme arar.
func handleSearchStart(mc *services.MatchConn, hub *services.MatchHub, msg map[string]interface{}) {
	tmdbIDFloat, ok := msg["tmdbId"].(float64)
	if !ok || tmdbIDFloat <= 0 {
		mc.SendJSON(map[string]interface{}{
			"type":    "error",
			"message": "Geçerli bir tmdbId gerekli",
		})
		return
	}
	tmdbID := int(tmdbIDFloat)
	localOnly, _ := msg["localOnly"].(bool)

	// Hub'da tmdbID'yi güncelle (disconnect olursa havuzdan çıkarılması için)
	mc.TmdbID = tmdbID
	hub.SetTmdbID(mc.UserID, tmdbID)

	// CheckForMatch — havuza ekler ve eşleşme arar
	result, err := services.CheckForMatch(mc.UserID, tmdbID, localOnly)
	if err != nil {
		mc.SendJSON(map[string]interface{}{
			"type":    "error",
			"message": "Eşleşme kontrolü başarısız: " + err.Error(),
		})
		return
	}

	if result != nil {
		// 🎉 Eşleşme bulundu!
		// Kimlik tespiti: Ben kimim, karşımdaki kim?
		targetUserID := result.User2ID
		targetUserName := result.User2Name
		if result.User2ID == mc.UserID {
			targetUserID = result.User1ID
			targetUserName = result.User1Name
		}

		// Oda'yı hub'a kaydet (accept/reject olayları için)
		hub.RegisterRoom(result.RoomID, result.User1ID, result.User2ID)

		// 1) Bana match_found gönder
		mc.SendJSON(map[string]interface{}{
			"type":           "match_found",
			"roomId":         result.RoomID,
			"targetUserId":   targetUserID,
			"targetUserName": targetUserName,
			"tmdbId":         result.TmdbID,
			"movieName":      result.MovieName,
		})

		// 2) Karşı tarafa match_found gönder
		otherTargetUserID := result.User1ID
		otherTargetUserName := result.User1Name
		if otherTargetUserID == targetUserID {
			otherTargetUserID = result.User2ID
			otherTargetUserName = result.User2Name
		}

		hub.SendToUser(targetUserID, map[string]interface{}{
			"type":           "match_found",
			"roomId":         result.RoomID,
			"targetUserId":   otherTargetUserID,
			"targetUserName": otherTargetUserName,
			"tmdbId":         result.TmdbID,
			"movieName":      result.MovieName,
		})

		log.Printf("🔔 WS match_found push: %s ↔ %s (room: %s)", mc.UserID, targetUserID, result.RoomID)
	} else {
		// Eşleşme yok — bekleme modunda. queue_update gönder.
		count, _ := services.GetTotalQueueCount()
		mc.SendJSON(map[string]interface{}{
			"type":       "searching",
			"message":    "Eşleşme aranıyor...",
			"queueCount": count,
		})
	}
}

// handleAccept — Kullanıcı eşleşmeyi kabul etti.
func handleAccept(mc *services.MatchConn, hub *services.MatchHub, msg map[string]interface{}) {
	roomID, _ := msg["roomId"].(string)
	targetUserID, _ := msg["targetUserId"].(string)
	if roomID == "" {
		mc.SendJSON(map[string]interface{}{
			"type":    "error",
			"message": "roomId gerekli",
		})
		return
	}

	result, err := services.AcceptMatchAndGetRoom(mc.UserID, roomID, targetUserID)
	if err != nil {
		mc.SendJSON(map[string]interface{}{
			"type":    "error",
			"message": "Kabul hatası: " + err.Error(),
		})
		return
	}

	bothAccepted, _ := result["bothAccepted"].(bool)

	if bothAccepted {
		finalRoomID, _ := result["roomId"].(string)
		// İki tarafa da both_accepted gönder
		hub.SendToRoom(roomID, map[string]interface{}{
			"type":   "both_accepted",
			"roomId": finalRoomID,
		})
		hub.UnregisterRoom(roomID)
		log.Printf("✅ WS both_accepted: room %s", roomID)
	} else {
		// Karşı tarafa "diğer kişi kabul etti" bilgisi gönder
		hub.SendToOther(roomID, mc.UserID, map[string]interface{}{
			"type":   "partner_accepted",
			"roomId": roomID,
		})
		// Bana da onay gönder
		mc.SendJSON(map[string]interface{}{
			"type":   "accepted",
			"roomId": roomID,
		})
	}
}

// handleReject — Kullanıcı eşleşmeyi reddetti.
// ★ KRİTİK: Karşı tarafın ekranını ANINDA kapatır! ★
func handleReject(mc *services.MatchConn, hub *services.MatchHub, msg map[string]interface{}) {
	roomID, _ := msg["roomId"].(string)
	targetUserID, _ := msg["targetUserId"].(string)
	if roomID == "" {
		mc.SendJSON(map[string]interface{}{
			"type":    "error",
			"message": "roomId gerekli",
		})
		return
	}

	// Backend'de Redis temizliğini yap
	err := services.RejectMatch(mc.UserID, roomID, targetUserID)
	if err != nil {
		log.Printf("⚠️ WS reject hatası: %v", err)
	}

	// ★★★ Karşı tarafa ANINDA rejected push et → Modal kapanır! ★★★
	hub.SendToOther(roomID, mc.UserID, map[string]interface{}{
		"type":   "rejected",
		"roomId": roomID,
	})

	// Kendime de onay gönder
	mc.SendJSON(map[string]interface{}{
		"type":   "rejected",
		"roomId": roomID,
	})

	hub.UnregisterRoom(roomID)
	log.Printf("🛑 WS rejected: %s reddetti (room: %s)", mc.UserID, roomID)
}

// handleCancel — Kullanıcı eşleşme aramasını iptal etti.
func handleCancel(mc *services.MatchConn, hub *services.MatchHub, msg map[string]interface{}) {
	tmdbIDFloat, _ := msg["tmdbId"].(float64)
	tmdbID := int(tmdbIDFloat)
	if tmdbID <= 0 {
		tmdbID = mc.TmdbID
	}

	if tmdbID > 0 {
		services.CancelMatchRequest(mc.UserID, tmdbID)
	}

	mc.TmdbID = 0
	hub.SetTmdbID(mc.UserID, 0)

	mc.SendJSON(map[string]interface{}{
		"type":    "cancelled",
		"message": "Arama iptal edildi",
	})
}
