package services

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// ────────────────────────────────────────────────────────────────────
// MatchHub — Eşleşme arayan kullanıcıların WebSocket bağlantılarını
// merkezi olarak yöneten hub. Tüm push olayları buradan geçer.
// ────────────────────────────────────────────────────────────────────

const (
	MatchWriteWait  = 10 * time.Second
	MatchPongWait   = 30 * time.Second
	MatchPingPeriod = (MatchPongWait * 9) / 10
	MatchMaxMsgSize = 4096
)

// MatchConn tek bir kullanıcının WebSocket bağlantısını temsil eder.
type MatchConn struct {
	Hub    *MatchHub
	Conn   *websocket.Conn
	UserID string
	TmdbID int // Aktif olarak aradığı filmin ID'si (0 = aramıyor)
	Send   chan []byte
	done   chan struct{}
}

// MatchHub tüm aktif eşleşme WS bağlantılarını yönetir.
type MatchHub struct {
	mu    sync.RWMutex
	conns map[string]*MatchConn   // userID → bağlantı
	rooms map[string][2]string    // roomID → [user1ID, user2ID]
}

var matchHub *MatchHub

// InitMatchHub hub'ı başlatır. main.go'dan çağrılır.
func InitMatchHub() {
	matchHub = &MatchHub{
		conns: make(map[string]*MatchConn),
		rooms: make(map[string][2]string),
	}
	log.Println("✅ MatchHub başlatıldı")
}

// GetMatchHub global hub referansını döner.
func GetMatchHub() *MatchHub {
	return matchHub
}

// ──────────── Hub Metodları ────────────

// Register yeni bir kullanıcı bağlantısını hub'a ekler.
// Eğer aynı kullanıcının eski bağlantısı varsa kapatır.
func (h *MatchHub) Register(mc *MatchConn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// Eski bağlantı varsa temizle
	if old, ok := h.conns[mc.UserID]; ok {
		select {
		case <-old.done:
			// Zaten kapalı
		default:
			close(old.done)
		}
		old.Conn.Close()
	}

	h.conns[mc.UserID] = mc
	log.Printf("🔌 MatchHub: %s bağlandı (toplam: %d)", mc.UserID, len(h.conns))
}

// Unregister kullanıcıyı hub'dan çıkarır ve bağlantısını kapatır.
func (h *MatchHub) Unregister(userID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if mc, ok := h.conns[userID]; ok {
		select {
		case <-mc.done:
		default:
			close(mc.done)
		}
		mc.Conn.Close()
		delete(h.conns, userID)

		// Eğer arama yapıyorsa havuzdan da çıkar
		if mc.TmdbID > 0 {
			go CancelMatchRequest(userID, mc.TmdbID)
		}

		log.Printf("🔌 MatchHub: %s ayrıldı (toplam: %d)", userID, len(h.conns))
	}
}

// RegisterRoom oda-kullanıcı eşlemesini hub'a kaydeder.
// Accept/Reject olaylarında karşı tarafı bulmak için kullanılır.
func (h *MatchHub) RegisterRoom(roomID, user1ID, user2ID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.rooms[roomID] = [2]string{user1ID, user2ID}
}

// UnregisterRoom oda kaydını siler.
func (h *MatchHub) UnregisterRoom(roomID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.rooms, roomID)
}

// GetRoomUsers oda'daki kullanıcı ID'lerini döner.
func (h *MatchHub) GetRoomUsers(roomID string) (string, string, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	users, ok := h.rooms[roomID]
	if !ok {
		return "", "", false
	}
	return users[0], users[1], true
}

// IsConnected kullanıcının hub'a bağlı olup olmadığını döner.
func (h *MatchHub) IsConnected(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.conns[userID]
	return ok
}

// SetTmdbID kullanıcının aktif olarak aradığı filmi günceller.
func (h *MatchHub) SetTmdbID(userID string, tmdbID int) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	if mc, ok := h.conns[userID]; ok {
		mc.TmdbID = tmdbID
	}
}

// ──────────── Mesaj Gönderme ────────────

// SendToUser belirli bir kullanıcıya JSON event push eder.
func (h *MatchHub) SendToUser(userID string, event map[string]interface{}) {
	h.mu.RLock()
	mc, ok := h.conns[userID]
	h.mu.RUnlock()

	if !ok {
		return
	}

	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("⚠️ MatchHub: JSON marshal hatası: %v", err)
		return
	}

	select {
	case mc.Send <- data:
	case <-mc.done:
	default:
		log.Printf("⚠️ MatchHub: %s send buffer dolu, mesaj atıldı", userID)
	}
}

// SendToRoom oda'daki her iki kullanıcıya event push eder.
func (h *MatchHub) SendToRoom(roomID string, event map[string]interface{}) {
	h.mu.RLock()
	users, ok := h.rooms[roomID]
	h.mu.RUnlock()

	if !ok {
		return
	}

	h.SendToUser(users[0], event)
	h.SendToUser(users[1], event)
}

// SendToOther oda'daki DİĞER kullanıcıya event push eder (göndereni hariç tutar).
func (h *MatchHub) SendToOther(roomID, senderID string, event map[string]interface{}) {
	h.mu.RLock()
	users, ok := h.rooms[roomID]
	h.mu.RUnlock()

	if !ok {
		return
	}

	if users[0] == senderID {
		h.SendToUser(users[1], event)
	} else {
		h.SendToUser(users[0], event)
	}
}

// ──────────── WritePump ────────────

// WritePump Send kanalından gelen mesajları WS bağlantısına yazar.
// Her MatchConn için ayrı goroutine'de çalışır.
// InitDone done kanalını başlatır. Controller'dan çağrılır.
func (mc *MatchConn) InitDone() {
	mc.done = make(chan struct{})
}

// Done kanalını döner (okuma amaçlı).
func (mc *MatchConn) Done() <-chan struct{} {
	return mc.done
}

func (mc *MatchConn) WritePump() {
	ticker := time.NewTicker(MatchPingPeriod)
	defer func() {
		ticker.Stop()
		mc.Conn.Close()
	}()

	for {
		select {
		case <-mc.done:
			mc.Conn.WriteMessage(websocket.CloseMessage, []byte{})
			return

		case message, ok := <-mc.Send:
			mc.Conn.SetWriteDeadline(time.Now().Add(MatchWriteWait))
			if !ok {
				mc.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := mc.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("⚠️ MatchHub WritePump: %s yazma hatası: %v", mc.UserID, err)
				return
			}

		case <-ticker.C:
			mc.Conn.SetWriteDeadline(time.Now().Add(MatchWriteWait))
			if err := mc.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// SendJSON yardımcı metod — doğrudan bağlantı üzerinden JSON gönderir.
func (mc *MatchConn) SendJSON(event map[string]interface{}) {
	data, err := json.Marshal(event)
	if err != nil {
		return
	}
	select {
	case mc.Send <- data:
	case <-mc.done:
	default:
	}
}
