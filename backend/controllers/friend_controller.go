package controllers

import (
	"context"
	"log"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// SendFriendRequest — Karşılıklı Onay Mantığı:
// 1. Kendine istek atılamaz.
// 2. Zaten arkadaş olanlar tekrar istek atamaz.
// 3. Aynı yönde zaten pending istek varsa tekrar gönderilmez.
// 4. Karşı taraf daha önce istek atmışsa → anında arkadaşlık kurulur (pending kayıtlar silinir).
// 5. Hiçbiri yoksa → pending kaydı oluşturulur.
func SendFriendRequest() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		fromIDStr, ok := mustUserID(c)
		if !ok {
			return
		}
		fromID, ok := parseObjectIDOrBadRequest(c, fromIDStr, "kullanıcı kimliği")
		if !ok {
			return
		}

		var input struct {
			TargetUserID string `json:"targetUserId" binding:"required"`
		}
		if err := c.ShouldBindJSON(&input); err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "targetUserId zorunlu", err.Error())
			return
		}

		toID, ok := parseObjectIDOrBadRequest(c, input.TargetUserID, "hedef kullanıcı kimliği")
		if !ok {
			return
		}

		// 1. Kendine istek gönderme engeli
		if fromID == toID {
			errorResponse(c, http.StatusBadRequest, "SELF_REQUEST_FORBIDDEN", "Kendinize arkadaşlık isteği gönderemezsiniz", nil)
			return
		}

		userCol := config.GetCollection(config.DB, "users")
		friendReqCol := config.GetCollection(config.DB, "friend_requests")

		// 2. Zaten arkadaş mı?
		var fromUser models.User
		if err := userCol.FindOne(ctx, bson.M{"_id": fromID}).Decode(&fromUser); err != nil {
			errorResponse(c, http.StatusNotFound, "USER_NOT_FOUND", "Kullanıcı bulunamadı", err.Error())
			return
		}
		for _, fid := range fromUser.Friends {
			if fid == toID {
				errorResponse(c, http.StatusConflict, "ALREADY_FRIENDS", "Zaten arkadaşsınız", nil)
				return
			}
		}

		// 3. Aynı yönde pending istek var mı? (from→to daha önce atıldı mı?)
		existing := friendReqCol.FindOne(ctx, bson.M{"from": fromID, "to": toID, "status": "pending"})
		if existing.Err() == nil {
			c.JSON(http.StatusConflict, gin.H{
				"status":  "pending",
				"message": "Zaten arkadaşlık isteği gönderildi, karşı tarafın onayı bekleniyor",
			})
			return
		}

		// 4. Karşı yönde pending istek var mı? (to→from daha önce atıldı mı?) → MUTUAL onay!
		reverseResult := friendReqCol.FindOne(ctx, bson.M{"from": toID, "to": fromID, "status": "pending"})
		if reverseResult.Err() == nil {
			// Karşılıklı istek! Her iki pending kaydı sil, arkadaşlık kur.
			_, _ = friendReqCol.DeleteMany(ctx, bson.M{
				"$or": bson.A{
					bson.M{"from": fromID, "to": toID},
					bson.M{"from": toID, "to": fromID},
				},
			})

			// Her iki kullanıcının friends listesine birbirini ekle
			_, err1 := userCol.UpdateOne(ctx, bson.M{"_id": fromID},
				bson.M{"$addToSet": bson.M{"friends": toID}})
			_, err2 := userCol.UpdateOne(ctx, bson.M{"_id": toID},
				bson.M{"$addToSet": bson.M{"friends": fromID}})

			if err1 != nil || err2 != nil {
				log.Printf("[FRIEND] arkadaşlık yazma hatası: err1=%v err2=%v", err1, err2)
				errorResponse(c, http.StatusInternalServerError, "FRIENDSHIP_CREATE_FAILED", "Arkadaşlık oluşturulamadı", gin.H{"err1": err1, "err2": err2})
				return
			}

			log.Printf("[FRIEND] Karşılıklı onay! %s ↔ %s artık arkadaş", fromIDStr, input.TargetUserID)
			notifyFriendStatusChanged(fromIDStr, input.TargetUserID)
			c.JSON(http.StatusOK, gin.H{
				"status":  "friends",
				"message": "Artık arkadaşsınız! 🎉",
			})
			return
		}

		// 5. Hiçbiri yoksa → pending kayıt oluştur
		req := models.FriendRequest{
			ID:        primitive.NewObjectID(),
			From:      fromID,
			To:        toID,
			Status:    "pending",
			CreatedAt: time.Now(),
		}
		if _, err := friendReqCol.InsertOne(ctx, req); err != nil {
			errorResponse(c, http.StatusInternalServerError, "FRIEND_REQUEST_CREATE_FAILED", "İstek kaydedilemedi", err.Error())
			return
		}

		log.Printf("[FRIEND] Pending istek: %s → %s", fromIDStr, input.TargetUserID)

		// Bildirim ekle
		notifCol := config.GetCollection(config.DB, "notifications")
		_, _ = notifCol.InsertOne(ctx, bson.M{
			"userId":    input.TargetUserID,
			"type":      "friend_request",
			"senderId":  fromIDStr,
			"title":     "Yeni Arkadaşlık İsteği",
			"message":   fromUser.Username + " sana arkadaşlık isteği gönderdi.",
			"avatar":    fromUser.AvatarURL,
			"isRead":    false,
			"createdAt": time.Now(),
		})

		notifyFriendStatusChanged(fromIDStr, input.TargetUserID)
		c.JSON(http.StatusCreated, gin.H{
			"status":  "pending",
			"message": "Arkadaşlık isteği gönderildi! Karşı taraf da onaylarsa arkadaş olacaksınız.",
		})
	}
}

// GetFriends — Kullanıcının arkadaş listesini döner
func GetFriends() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDStr, ok := mustUserID(c)
		if !ok {
			return
		}
		userID, ok := parseObjectIDOrBadRequest(c, userIDStr, "kullanıcı kimliği")
		if !ok {
			return
		}

		userCol := config.GetCollection(config.DB, "users")

		// Kendi profilini çek (friends listesi ile)
		var user models.User
		if err := userCol.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
			errorResponse(c, http.StatusNotFound, "USER_NOT_FOUND", "Kullanıcı bulunamadı", err.Error())
			return
		}

		if len(user.Friends) == 0 {
			c.JSON(http.StatusOK, gin.H{"friends": []interface{}{}})
			return
		}

		// Arkadaşların detaylarını çek
		cursor, err := userCol.Find(ctx, bson.M{"_id": bson.M{"$in": user.Friends}},
			options.Find().SetProjection(bson.M{"password": 0}))
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "FRIENDS_FETCH_FAILED", "Arkadaşlar getirilemedi", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var friends []bson.M
		if err := cursor.All(ctx, &friends); err != nil {
			errorResponse(c, http.StatusInternalServerError, "FRIENDS_DECODE_FAILED", "Arkadaş verisi okunamadı", err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{"friends": friends})
	}
}

// RemoveFriend — Arkadaşlıktan çıkarma (karşılıklı)
func RemoveFriend() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDStr, ok := mustUserID(c)
		if !ok {
			return
		}
		userID, ok := parseObjectIDOrBadRequest(c, userIDStr, "kullanıcı kimliği")
		if !ok {
			return
		}

		friendIDStr := c.Param("friendId")
		friendID, ok := parseObjectIDOrBadRequest(c, friendIDStr, "arkadaş kimliği")
		if !ok {
			return
		}

		userCol := config.GetCollection(config.DB, "users")

		// Her iki taraftan da sil ($pull ile)
		_, err1 := userCol.UpdateOne(ctx, bson.M{"_id": userID},
			bson.M{"$pull": bson.M{"friends": friendID}})
		_, err2 := userCol.UpdateOne(ctx, bson.M{"_id": friendID},
			bson.M{"$pull": bson.M{"friends": userID}})

		if err1 != nil || err2 != nil {
			errorResponse(c, http.StatusInternalServerError, "FRIEND_REMOVE_FAILED", "Arkadaşlık kaldırılamadı", gin.H{"err1": err1, "err2": err2})
			return
		}

		// Eğer aynı yönde bir pending istek kalmışsa onu da temizle
		friendReqCol := config.GetCollection(config.DB, "friend_requests")
		_, _ = friendReqCol.DeleteMany(ctx, bson.M{
			"$or": bson.A{
				bson.M{"from": userID, "to": friendID},
				bson.M{"from": friendID, "to": userID},
			},
		})

		notifyFriendStatusChanged(userIDStr, friendIDStr)
		c.JSON(http.StatusOK, gin.H{"message": "Arkadaşlıktan çıkarıldı"})
	}
}

// notifyFriendStatusChanged - iki kullanıcı arasındaki aktif sohbet odasına
// friend_status_changed olayı yollar; chat içindeki butonlar anında güncellenir.
func notifyFriendStatusChanged(userA, userB string) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		roomID, err := findChatRoomIDBetweenUsers(ctx, userA, userB)
		if err != nil {
			return
		}
		if roomID == "" {
			return
		}

		msg := ChatMessage{
			Type:       "friend_status_changed",
			RoomID:     roomID,
			SenderID:   userA,
			ReceiverID: userB,
			Timestamp:  time.Now().Unix(),
		}
		broadcastToRoom(roomID, msg)
	}()
}

// GetFriendStatus — İki kullanıcı arasındaki arkadaşlık durumunu döner
// Dönebilecek status değerleri: "none", "pending_sent", "pending_received", "friends"
func GetFriendStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDStr, ok := mustUserID(c)
		if !ok {
			return
		}
		userID, ok := parseObjectIDOrBadRequest(c, userIDStr, "kullanıcı kimliği")
		if !ok {
			return
		}

		targetIDStr := c.Param("targetId")
		targetID, ok := parseObjectIDOrBadRequest(c, targetIDStr, "hedef kimliği")
		if !ok {
			return
		}

		userCol := config.GetCollection(config.DB, "users")
		friendReqCol := config.GetCollection(config.DB, "friend_requests")

		// Arkadaş mı?
		var user models.User
		if err := userCol.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err == nil {
			for _, fid := range user.Friends {
				if fid == targetID {
					c.JSON(http.StatusOK, gin.H{"status": "friends"})
					return
				}
			}
		}

		// Pending istek var mı?
		sentResult := friendReqCol.FindOne(ctx, bson.M{"from": userID, "to": targetID, "status": "pending"})
		if sentResult.Err() == nil {
			c.JSON(http.StatusOK, gin.H{"status": "pending_sent"})
			return
		}

		receivedResult := friendReqCol.FindOne(ctx, bson.M{"from": targetID, "to": userID, "status": "pending"})
		if receivedResult.Err() != mongo.ErrNoDocuments {
			c.JSON(http.StatusOK, gin.H{"status": "pending_received"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "none"})
	}
}
