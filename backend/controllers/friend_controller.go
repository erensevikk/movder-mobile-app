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
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		fromIDStr := c.GetString("userId")
		fromID, err := primitive.ObjectIDFromHex(fromIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği"})
			return
		}

		var input struct {
			TargetUserID string `json:"targetUserId" binding:"required"`
		}
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "targetUserId zorunlu"})
			return
		}

		toID, err := primitive.ObjectIDFromHex(input.TargetUserID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz hedef kullanıcı kimliği"})
			return
		}

		// 1. Kendine istek gönderme engeli
		if fromID == toID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Kendinize arkadaşlık isteği gönderemezsiniz"})
			return
		}

		userCol := config.GetCollection(config.DB, "users")
		friendReqCol := config.GetCollection(config.DB, "friend_requests")

		// 2. Zaten arkadaş mı?
		var fromUser models.User
		if err := userCol.FindOne(ctx, bson.M{"_id": fromID}).Decode(&fromUser); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
			return
		}
		for _, fid := range fromUser.Friends {
			if fid == toID {
				c.JSON(http.StatusConflict, gin.H{"error": "Zaten arkadaşsınız"})
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
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Arkadaşlık oluşturulamadı"})
				return
			}

			log.Printf("[FRIEND] Karşılıklı onay! %s ↔ %s artık arkadaş", fromIDStr, input.TargetUserID)
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
			c.JSON(http.StatusInternalServerError, gin.H{"error": "İstek kaydedilemedi"})
			return
		}

		log.Printf("[FRIEND] Pending istek: %s → %s", fromIDStr, input.TargetUserID)
		c.JSON(http.StatusCreated, gin.H{
			"status":  "pending",
			"message": "Arkadaşlık isteği gönderildi! Karşı taraf da onaylarsa arkadaş olacaksınız.",
		})
	}
}

// GetFriends — Kullanıcının arkadaş listesini döner
func GetFriends() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDStr := c.GetString("userId")
		userID, err := primitive.ObjectIDFromHex(userIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği"})
			return
		}

		userCol := config.GetCollection(config.DB, "users")

		// Kendi profilini çek (friends listesi ile)
		var user models.User
		if err := userCol.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
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
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Arkadaşlar getirilemedi"})
			return
		}
		defer cursor.Close(ctx)

		var friends []bson.M
		if err := cursor.All(ctx, &friends); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Arkadaş verisi okunamadı"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"friends": friends})
	}
}

// RemoveFriend — Arkadaşlıktan çıkarma (karşılıklı)
func RemoveFriend() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDStr := c.GetString("userId")
		userID, err := primitive.ObjectIDFromHex(userIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği"})
			return
		}

		friendIDStr := c.Param("friendId")
		friendID, err := primitive.ObjectIDFromHex(friendIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz arkadaş kimliği"})
			return
		}

		userCol := config.GetCollection(config.DB, "users")

		// Her iki taraftan da sil ($pull ile)
		_, err1 := userCol.UpdateOne(ctx, bson.M{"_id": userID},
			bson.M{"$pull": bson.M{"friends": friendID}})
		_, err2 := userCol.UpdateOne(ctx, bson.M{"_id": friendID},
			bson.M{"$pull": bson.M{"friends": userID}})

		if err1 != nil || err2 != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Arkadaşlık kaldırılamadı"})
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

		c.JSON(http.StatusOK, gin.H{"message": "Arkadaşlıktan çıkarıldı"})
	}
}

// GetFriendStatus — İki kullanıcı arasındaki arkadaşlık durumunu döner
// Dönebilecek status değerleri: "none", "pending_sent", "pending_received", "friends"
func GetFriendStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDStr := c.GetString("userId")
		userID, err := primitive.ObjectIDFromHex(userIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği"})
			return
		}

		targetIDStr := c.Param("targetId")
		targetID, err := primitive.ObjectIDFromHex(targetIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz hedef kimliği"})
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
