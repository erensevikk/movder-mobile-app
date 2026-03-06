package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"golang.org/x/crypto/bcrypt"
)

// RegisterUser — Kullanıcı kaydı
// Input doğrulama: Gin binding tag'leri (required, email, min, max)
// Güvenlik: bcrypt ile şifre hash'leme, email tekrarı kontrolü
func RegisterUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user models.User

		// 1. Input doğrulama (binding tag'leri çalışır)
		if err := c.ShouldBindJSON(&user); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		// 2. Kullanıcı adı / email tekrarı kontrolü (tek seferde tüm hataları dön)
		var existingUser models.User
		usernameTaken := userCollection.FindOne(ctx, bson.M{"username": user.Username}).Decode(&existingUser) == nil
		emailTaken := userCollection.FindOne(ctx, bson.M{"email": user.Email}).Decode(&existingUser) == nil

		if usernameTaken || emailTaken {
			fields := make([]string, 0, 2)
			if usernameTaken {
				fields = append(fields, "username")
			}
			if emailTaken {
				fields = append(fields, "email")
			}

			log.Printf("[REGISTER] duplicate precheck -> username=%t email=%t fields=%v usernameValue=%s emailValue=%s", usernameTaken, emailTaken, fields, user.Username, user.Email)
			c.JSON(http.StatusConflict, gin.H{
				"error":  "Kullanıcı adı veya e-posta zaten kullanımda!",
				"fields": fields,
			})
			return
		}

		// 4. Şifreyi bcrypt ile hash'le
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Şifre işlenemedi!"})
			return
		}
		user.Password = string(hashedPassword)

		// 5. ID ve zaman damgası ata
		user.ID = primitive.NewObjectID()
		user.CreatedAt = time.Now()

		// 6. Veritabanına yaz
		_, err = userCollection.InsertOne(ctx, user)
		if err != nil {
			if mongo.IsDuplicateKeyError(err) {
				errText := strings.ToLower(err.Error())
				log.Printf("[REGISTER] duplicate on insert -> err=%s", err.Error())
				if strings.Contains(errText, "username") {
					c.JSON(http.StatusConflict, gin.H{"error": "Kullanıcı adı zaten alınmış!", "field": "username"})
					return
				}
				if strings.Contains(errText, "email") {
					c.JSON(http.StatusConflict, gin.H{"error": "Bu e-posta adresi zaten kayıtlı!", "field": "email"})
					return
				}
				c.JSON(http.StatusConflict, gin.H{"error": "Kullanıcı adı veya e-posta zaten kullanımda!"})
				return
			}

			errText := strings.ToLower(err.Error())
			log.Printf("[REGISTER] insert validation/internal error -> err=%s", err.Error())
			if strings.Contains(errText, "birth_date") {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Doğum tarihi zorunlu.", "field": "birthDate"})
				return
			}
			if strings.Contains(errText, "city") {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Şehir zorunlu.", "field": "city"})
				return
			}

			c.JSON(http.StatusInternalServerError, gin.H{
				"error":  "Kullanıcı oluşturulamadı!",
				"detail": err.Error(),
			})
			return
		}

		// 7. Yeni kullanıcı için "Favori Filmler" listesini otomatik oluştur
		listColl := config.GetCollection(config.DB, "lists")
		_, listErr := listColl.InsertOne(ctx, models.List{
			UserID:      user.ID.Hex(),
			Name:        "Favori Filmler",
			Description: "Favori filmlerim",
			IsPublic:    true,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		})
		if listErr != nil {
			log.Printf("[REGISTER] Favori Filmler listesi olusturulamadi -> userId=%s err=%v", user.ID.Hex(), listErr)
			// Liste hatası kritik değil, kayıt yine de başarılı sayılır
		} else {
			log.Printf("[REGISTER] Favori Filmler listesi olusturuldu -> userId=%s", user.ID.Hex())
		}

		jwtSecret := config.GetEnv("JWT_SECRET", "default_secret")
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"userId":   user.ID.Hex(),
			"email":    user.Email,
			"username": user.Username,
			"exp":      time.Now().Add(24 * time.Hour).Unix(),
		})

		tokenString, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Token üretilemedi!"})
			return
		}

		log.Printf("[REGISTER] success response -> userId=%s tokenIncluded=true autoLoginReady=true", user.ID.Hex())
		c.JSON(http.StatusCreated, gin.H{
			"message":  "Kullanıcı başarıyla oluşturuldu!",
			"userId":   user.ID,
			"username": user.Username,
			"token":    tokenString,
		})
	}
}

// LoginUser — Kullanıcı girişi
// Identifier (kullanıcı adı veya e-posta) ile bulur, bcrypt ile şifreyi doğrular, JWT token üretir
func LoginUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var input models.LoginInput

		// 1. Input doğrulama
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		// 2. Identifier'a göre email mi username mi karar ver
		//    @ karakteri varsa email olarak ara, yoksa username olarak ara
		var filter bson.M
		identifier := strings.TrimSpace(input.Identifier)
		if strings.Contains(identifier, "@") {
			filter = bson.M{"email": identifier}
			log.Printf("[LOGIN] email ile giriş denemesi -> identifier=%s", identifier)
		} else {
			filter = bson.M{"username": identifier}
			log.Printf("[LOGIN] username ile giriş denemesi -> identifier=%s", identifier)
		}

		var user models.User
		err := userCollection.FindOne(ctx, filter).Decode(&user)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Kullanıcı adı/e-posta veya şifre hatalı!"})
			return
		}

		// 3. Şifreyi doğrula
		err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(input.Password))
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Kullanıcı adı/e-posta veya şifre hatalı!"})
			return
		}

		// 4. JWT token üret
		jwtSecret := config.GetEnv("JWT_SECRET", "default_secret")
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"userId":   user.ID.Hex(),
			"email":    user.Email,
			"username": user.Username,
			"exp":      time.Now().Add(24 * time.Hour).Unix(),
		})

		tokenString, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Token üretilemedi!"})
			return
		}

		log.Printf("[LOGIN] success -> userId=%s username=%s", user.ID.Hex(), user.Username)
		c.JSON(http.StatusOK, gin.H{
			"message":  "Giriş başarılı!",
			"token":    tokenString,
			"userId":   user.ID,
			"username": user.Username,
		})
	}
}

// GetProfile — JWT ile korunan profil endpoint'i
func GetProfile() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")
		var user models.User
		err = userCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı!"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"userId":             user.ID.Hex(),
			"username":           user.Username,
			"email":              user.Email,
			"city":               user.City,
			"birthDate":          user.BirthDate,
			"description":        user.Description,
			"avatarUrl":          user.AvatarURL,
			"coverUrl":           user.CoverURL,
			"letterboxdImported": user.LetterboxdImported,
			"watchHistory":       user.WatchHistory,
			"createdAt":          user.CreatedAt,
			"privacySettings":    userPrivacySettings(user),
		})
	}
}

// SearchUsers — username'e göre kullanıcı arar
func SearchUsers() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		userID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		query := strings.TrimSpace(c.Query("q"))
		if len(query) < 2 {
			c.JSON(http.StatusOK, gin.H{"users": []interface{}{}})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")
		var viewer models.User
		if err := userCollection.FindOne(ctx, bson.M{"_id": userID}).Decode(&viewer); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı!"})
			return
		}

		excludedIDs := append([]primitive.ObjectID{userID}, viewer.BlockedUsers...)
		filter := bson.M{
			"_id": bson.M{"$nin": excludedIDs},
			"username": bson.M{
				"$regex":   regexp.QuoteMeta(query),
				"$options": "i",
			},
			"blocked_users":                        bson.M{"$ne": userID},
			"privacy_settings.search_discoverable": bson.M{"$ne": false},
		}

		findOptions := options.Find().
			SetLimit(20).
			SetProjection(bson.M{"password": 0, "email": 0, "friends": 0, "blocked_users": 0}).
			SetSort(bson.M{"username": 1})

		cursor, err := userCollection.Find(ctx, filter, findOptions)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcılar aranamadı"})
			return
		}
		defer cursor.Close(ctx)

		var users []bson.M
		if err := cursor.All(ctx, &users); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcılar okunamadı"})
			return
		}

		for _, u := range users {
			if id, ok := u["_id"].(primitive.ObjectID); ok {
				u["userId"] = id.Hex()
				u["_id"] = id.Hex()
			}

			// Mongo'da snake_case (avatar_url) gelen alanı API cevabında camelCase (avatarUrl)
			// olarak da normalize et ki mobil taraf tutarlı anahtar ile okuyabilsin.
			if avatarURL, ok := u["avatar_url"]; ok {
				u["avatarUrl"] = avatarURL
			}
		}

		c.JSON(http.StatusOK, gin.H{"users": users})
	}
}

// GetUserProfile — Başka bir kullanıcının profilini döner (izleme durumu gizlilik kuralı ile)
func GetUserProfile() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		viewerIDHex := c.GetString("userId")
		viewerID, err := primitive.ObjectIDFromHex(viewerIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		targetIDHex := c.Param("targetId")
		targetID, err := primitive.ObjectIDFromHex(targetIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz hedef kullanıcı kimliği!"})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		var viewer models.User
		if err := userCollection.FindOne(ctx, bson.M{"_id": viewerID}).Decode(&viewer); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı!"})
			return
		}

		var target models.User
		if err := userCollection.FindOne(ctx, bson.M{"_id": targetID}).Decode(&target); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Hedef kullanıcı bulunamadı!"})
			return
		}

		isFriend := containsObjectID(viewer.Friends, targetID)
		isMatched := areUsersMatched(ctx, viewerIDHex, targetIDHex)
		privacy := userPrivacySettings(target)
		canSeeProfileDetails := canViewerSeeProfileDetails(viewerID, targetID, isFriend, privacy)
		canSeeWatching := canViewerSeeWatching(viewerIDHex, viewerID, targetID, isFriend, isMatched, privacy)

		response := gin.H{
			"userId":               target.ID.Hex(),
			"username":             target.Username,
			"avatarUrl":            target.AvatarURL,
			"isFriend":             isFriend,
			"isMatched":            isMatched,
			"privacySettings":      privacy,
			"canSeeProfileDetails": canSeeProfileDetails,
			"canSeeWatching":       canSeeWatching,
			"watching":             false,
		}

		if canSeeProfileDetails {
			response["city"] = target.City
			response["description"] = target.Description
			response["coverUrl"] = target.CoverURL
			response["createdAt"] = target.CreatedAt
			response["watchHistory"] = target.WatchHistory
			response["letterboxdImported"] = target.LetterboxdImported
		}

		if canSeeWatching {
			watchKey := fmt.Sprintf("watching:%s", target.ID.Hex())
			if data, err := config.RedisClient.Get(ctx, watchKey).Result(); err == nil {
				var status models.WatchStatus
				if jsonErr := json.Unmarshal([]byte(data), &status); jsonErr == nil {
					response["watching"] = true
					response["status"] = status
					response["watchingFor"] = fmt.Sprintf("%d dakika", int(time.Since(status.StartedAt).Minutes()))
				}
			}
		}

		c.JSON(http.StatusOK, response)
	}
}

func containsObjectID(list []primitive.ObjectID, target primitive.ObjectID) bool {
	for _, item := range list {
		if item == target {
			return true
		}
	}
	return false
}

func areUsersMatched(ctx context.Context, userA, userB string) bool {
	chatroomCol := config.GetCollection(config.DB, "chatrooms")
	filter := bson.M{
		"$and": bson.A{
			bson.M{"status": bson.M{"$ne": "unmatched"}},
			bson.M{
				"$or": bson.A{
					bson.M{"user1Id": userA, "user2Id": userB},
					bson.M{"user1Id": userB, "user2Id": userA},
				},
			},
		},
	}

	err := chatroomCol.FindOne(ctx, filter).Err()
	if err == mongo.ErrNoDocuments {
		log.Printf("[REDIS-KEYS-REFAC] areUsersMatched mongo result=false userA=%s userB=%s", userA, userB)
		return false
	}
	if err != nil {
		log.Printf("[REDIS-KEYS-REFAC] areUsersMatched mongo error userA=%s userB=%s err=%v", userA, userB, err)
		return false
	}

	log.Printf("[REDIS-KEYS-REFAC] areUsersMatched mongo result=true userA=%s userB=%s", userA, userB)
	return true
}

// BlockUser — Kullanıcıyı engeller
func BlockUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		userID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		targetIDHex := c.Param("targetId")
		targetID, err := primitive.ObjectIDFromHex(targetIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz hedef kullanıcı kimliği!"})
			return
		}

		if userID == targetID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Kendinizi engelleyemezsiniz"})
			return
		}

		userCol := config.GetCollection(config.DB, "users")

		// 1. BlockedUsers'a ekle ve arkadaşlıktan çıkar
		_, err = userCol.UpdateOne(ctx, bson.M{"_id": userID}, bson.M{
			"$addToSet": bson.M{"blocked_users": targetID},
			"$pull":     bson.M{"friends": targetID},
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcı engellenemedi"})
			return
		}

		// Karşı tarafın arkadaş listesinden de çıkar
		_, _ = userCol.UpdateOne(ctx, bson.M{"_id": targetID}, bson.M{
			"$pull": bson.M{"friends": userID},
		})

		// 2. Varsa pending arkadaşlık isteklerini sil
		friendReqCol := config.GetCollection(config.DB, "friend_requests")
		_, _ = friendReqCol.DeleteMany(ctx, bson.M{
			"$or": bson.A{
				bson.M{"from": userID, "to": targetID},
				bson.M{"from": targetID, "to": userID},
			},
		})

		// 3. Varsa o anki eşleşmeyi sonlandır (Oda bulunuyorsa websocket üzerinden unmatch yolla)
		notifyUnmatch(userIDHex, targetIDHex)

		c.JSON(http.StatusOK, gin.H{"message": "Kullanıcı engellendi"})
	}
}

// UnmatchUser — Eşleşmeyi İptal Eder (yalnızca aktif sohbeti koparır ve varsa arkadaşlığı siler)
func UnmatchUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		userID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		targetIDHex := c.Param("targetId")
		targetID, err := primitive.ObjectIDFromHex(targetIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz hedef kullanıcı kimliği!"})
			return
		}

		// 1. Arkadaşlıktan çıkar ve birbirini unmatched_users listesine ekle
		userCol := config.GetCollection(config.DB, "users")
		_, _ = userCol.UpdateOne(ctx, bson.M{"_id": userID}, bson.M{
			"$pull":     bson.M{"friends": targetID},
			"$addToSet": bson.M{"unmatched_users": targetID},
		})
		_, _ = userCol.UpdateOne(ctx, bson.M{"_id": targetID}, bson.M{
			"$pull":     bson.M{"friends": userID},
			"$addToSet": bson.M{"unmatched_users": userID},
		})

		// 2. Varsa pending istekleri sil
		friendReqCol := config.GetCollection(config.DB, "friend_requests")
		_, _ = friendReqCol.DeleteMany(ctx, bson.M{
			"$or": bson.A{
				bson.M{"from": userID, "to": targetID},
				bson.M{"from": targetID, "to": userID},
			},
		})

		// 3. Eşleşmeyi sonlandır ve odalara bildir
		notifyUnmatch(userIDHex, targetIDHex)

		c.JSON(http.StatusOK, gin.H{"message": "Eşleşme iptal edildi"})
	}
}

// notifyUnmatch, iki kullanıcının eğer aktif bir odası varsa oradaki websocketlere unmatch tipi mesaj yollar
func notifyUnmatch(u1, u2 string) {
	// Chatroom'u "unmatched" olarak işaretle
	ctx := context.Background()
	roomsCol := config.GetCollection(config.DB, "chatrooms")
	roomsCol.UpdateMany(ctx,
		bson.M{"$or": bson.A{
			bson.M{"user1Id": u1, "user2Id": u2},
			bson.M{"user1Id": u2, "user2Id": u1},
		}},
		bson.M{"$set": bson.M{
			"status":      "unmatched",
			"unmatchedBy": u1,
			"unmatchedAt": time.Now(),
		}},
	)

	// Oda ID'sini genelde küçük olan ID - büyük olan ID şeklinde kurduğumuzu varsayarak buluruz
	var roomID string
	if u1 < u2 {
		roomID = u1 + "_" + u2
	} else {
		roomID = u2 + "_" + u1
	}

	broadcastToRoom(roomID, ChatMessage{
		Type:      "unmatch",
		SenderID:  u1,
		Content:   "Eşleşme iptal edildi",
		Timestamp: time.Now().Unix(),
		RoomID:    roomID,
	})

	// Odadaki katılımcıları boşalt / Redis'ten odayı silebiliriz
	config.RedisClient.Del(ctx, "chatroom:"+roomID)
}

// UpdateProfile — Kullanıcının profil bilgilerini (açıklama) ve profil fotoğrafını günceller
func UpdateProfile() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		// Description ve Avatar güncellemelerini al
		description := c.PostForm("description")

		file, err := c.FormFile("avatar")
		var avatarURL string
		if err == nil && file != nil {
			filename := fmt.Sprintf("%s_%s", userIDHex, file.Filename)
			savePath := "uploads/" + filename
			if err := c.SaveUploadedFile(file, savePath); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Fotoğraf kaydedilemedi"})
				return
			}
			avatarURL = "/uploads/" + filename
		}

		coverFile, coverErr := c.FormFile("cover")
		var coverURL string
		if coverErr == nil && coverFile != nil {
			filename := fmt.Sprintf("cover_%s_%s", userIDHex, coverFile.Filename)
			savePath := "uploads/" + filename
			if err := c.SaveUploadedFile(coverFile, savePath); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Kapak fotoğrafı kaydedilemedi"})
				return
			}
			coverURL = "/uploads/" + filename
		}

		updateFields := bson.M{}

		if _, ok := c.GetPostForm("description"); ok {
			updateFields["description"] = description
		}
		if avatarURL != "" {
			updateFields["avatar_url"] = avatarURL
		}
		if coverURL != "" {
			updateFields["cover_url"] = coverURL
		}
		// Kapak sil komutu
		if c.PostForm("delete_cover") == "true" {
			updateFields["cover_url"] = ""
		}

		if len(updateFields) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Güncellenecek veri bulunamadı"})
			return
		}

		_, err = userCollection.UpdateOne(ctx, bson.M{"_id": objectID}, bson.M{"$set": updateFields})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Profil güncellenemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":     "Profil başarıyla güncellendi",
			"description": description,
			"avatarUrl":   avatarURL,
			"coverUrl":    coverURL,
		})
	}
}

type UpdateAccountInput struct {
	Username string `json:"username" binding:"omitempty,min=3,max=30"`
	Email    string `json:"email" binding:"omitempty,email"`
	City     string `json:"city"`
}

type ChangePasswordInput struct {
	OldPassword string `json:"oldPassword" binding:"required"`
	NewPassword string `json:"newPassword" binding:"required,min=6"`
}

// UpdateAccountInfo — Kullanıcının hesap bilgilerini (username, email, city) günceller
func UpdateAccountInfo() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		var input UpdateAccountInput
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		// Çakışma kontrolü (username veya email değişiyorsa)
		if input.Username != "" {
			var existing models.User
			err := userCollection.FindOne(ctx, bson.M{"username": input.Username, "_id": bson.M{"$ne": objectID}}).Decode(&existing)
			if err == nil {
				c.JSON(http.StatusConflict, gin.H{"error": "Kullanıcı adı zaten kullanımda!"})
				return
			}
		}
		if input.Email != "" {
			var existing models.User
			err := userCollection.FindOne(ctx, bson.M{"email": input.Email, "_id": bson.M{"$ne": objectID}}).Decode(&existing)
			if err == nil {
				c.JSON(http.StatusConflict, gin.H{"error": "E-posta adresi zaten kullanımda!"})
				return
			}
		}

		updateFields := bson.M{}
		if input.Username != "" {
			updateFields["username"] = input.Username
		}
		if input.Email != "" {
			updateFields["email"] = input.Email
		}
		if input.City != "" {
			updateFields["city"] = input.City
		}

		if len(updateFields) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Güncellenecek veri bulunamadı"})
			return
		}

		_, err = userCollection.UpdateOne(ctx, bson.M{"_id": objectID}, bson.M{"$set": updateFields})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Hesap bilgileri güncellenemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Hesap bilgileri başarıyla güncellendi"})
	}
}

// ChangePassword — Kullanıcının şifresini günceller
func ChangePassword() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		var input ChangePasswordInput
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")

		var user models.User
		if err := userCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&user); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
			return
		}

		// Eski şifreyi doğrula
		if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(input.OldPassword)); err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Mevcut şifre hatalı!"})
			return
		}

		// Yeni şifreyi hashle
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(input.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Şifre işlenemedi!"})
			return
		}

		_, err = userCollection.UpdateOne(ctx, bson.M{"_id": objectID}, bson.M{"$set": bson.M{"password": string(hashedPassword)}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Şifre güncellenemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Şifre başarıyla güncellendi"})
	}
}

// DeleteAccount — Kullanıcı hesabını ve ilişkili tüm verileri siler
func DeleteAccount() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		// Önce eşleşmeleri unmatch yapalım
		var user models.User
		userCollection := config.GetCollection(config.DB, "users")
		if err := userCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&user); err == nil {
			for _, friendID := range user.Friends {
				notifyUnmatch(userIDHex, friendID.Hex())
				userCollection.UpdateOne(ctx, bson.M{"_id": friendID}, bson.M{"$pull": bson.M{"friends": objectID}})
			}
		}

		// Sonra tablolarını sil
		config.GetCollection(config.DB, "lists").DeleteMany(ctx, bson.M{"userId": userIDHex})
		config.GetCollection(config.DB, "friend_requests").DeleteMany(ctx, bson.M{"$or": bson.A{bson.M{"from": userIDHex}, bson.M{"to": userIDHex}}})
		config.GetCollection(config.DB, "notifications").DeleteMany(ctx, bson.M{"$or": bson.A{bson.M{"userId": userIDHex}, bson.M{"senderId": userIDHex}}})
		config.GetCollection(config.DB, "chat_rooms").DeleteMany(ctx, bson.M{"$or": bson.A{bson.M{"user1Id": userIDHex}, bson.M{"user2Id": userIDHex}}})

		_, err = userCollection.DeleteOne(ctx, bson.M{"_id": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Hesap silinemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Hesap ve ilişkili veriler başarıyla silindi"})
	}
}

// GetBlockedUsers — Engellenen kullanıcıları getirir
func GetBlockedUsers() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")
		var user models.User
		if err := userCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&user); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
			return
		}

		if len(user.BlockedUsers) == 0 {
			c.JSON(http.StatusOK, gin.H{"blockedUsers": []interface{}{}})
			return
		}

		cursor, err := userCollection.Find(ctx, bson.M{"_id": bson.M{"$in": user.BlockedUsers}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcılar getirilemedi"})
			return
		}
		defer cursor.Close(ctx)

		var users []models.User
		if err := cursor.All(ctx, &users); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcılar okunamadı"})
			return
		}

		var result []map[string]interface{}
		for _, u := range users {
			result = append(result, map[string]interface{}{
				"id":        u.ID.Hex(),
				"username":  u.Username,
				"avatarUrl": u.AvatarURL,
			})
		}

		c.JSON(http.StatusOK, gin.H{"blockedUsers": result})
	}
}

// UnblockUser — Kullanıcının engelini kaldırır
func UnblockUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		targetIDHex := c.Param("targetId")
		targetID, err := primitive.ObjectIDFromHex(targetIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz hedef kullanıcı kimliği!"})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")
		_, err = userCollection.UpdateOne(ctx, bson.M{"_id": objectID}, bson.M{"$pull": bson.M{"blocked_users": targetID}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Engellenen kullanıcı kaldırılamadı"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Kullanıcının engeli kaldırıldı"})
	}
}

// GetNotificationSettings — Kullanıcının mevcut bildirim ayarlarını getirir
func GetNotificationSettings() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		var user models.User
		userCollection := config.GetCollection(config.DB, "users")
		if err := userCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&user); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"notificationSettings": user.NotificationSettings})
	}
}

// UpdateNotificationSettings — Kullanıcının bildirim ayarlarını günceller
func UpdateNotificationSettings() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		userIDHex := c.GetString("userId")
		objectID, err := primitive.ObjectIDFromHex(userIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği!"})
			return
		}

		var input models.NotificationSettings
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz veri: " + err.Error()})
			return
		}

		userCollection := config.GetCollection(config.DB, "users")
		_, err = userCollection.UpdateOne(
			ctx,
			bson.M{"_id": objectID},
			bson.M{"$set": bson.M{"notification_settings": input}},
		)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Bildirim ayarları güncellenemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":              "Bildirim ayarları güncellendi",
			"notificationSettings": input,
		})
	}
}
