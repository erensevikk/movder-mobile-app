package controllers

import (
	"context"
	"log"
	"movder-backend/config"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// GetChatRoomsOptimized — Aggregation kullanan optimize edilmiş versiyon
// Bu fonksiyon N+1 query problemi çözer - tek aggregation ile tüm verileri alır
func GetChatRoomsOptimized() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		roomsCol := config.GetCollection(config.DB, "chatrooms")

		// Aggregation pipeline - tek sorguda tüm verileri al
		pipeline := []bson.M{
			{
				"$match": bson.M{
					"$or": bson.A{
						bson.M{"user1Id": userId},
						bson.M{"user2Id": userId},
					},
				},
			},
			{
				"$lookup": bson.M{
					"from": "messages",
					"let":  bson.M{"roomId": "$roomId"},
					"pipeline": []bson.M{
						{
							"$match": bson.M{
								"$expr": bson.M{"$eq": bson.A{"$roomId", "$$roomId"}},
								"type":  "message",
							},
						},
						{"$sort": bson.M{"timestamp": -1}},
						{"$limit": 1},
						{
							"$project": bson.M{
								"content":   1,
								"timestamp": 1,
								"senderId":  1,
								"status":    1,
							},
						},
					},
					"as": "lastMessageData",
				},
			},
			{
				"$lookup": bson.M{
					"from": "messages",
					"let":  bson.M{"roomId": "$roomId"},
					"pipeline": []bson.M{
						{
							"$match": bson.M{
								"$expr":    bson.M{"$eq": bson.A{"$roomId", "$$roomId"}},
								"senderId": bson.M{"$ne": userId},
								"type":     "message",
								"status":   bson.M{"$in": bson.A{"sent", "delivered"}},
							},
						},
						{"$count": "count"},
					},
					"as": "unreadData",
				},
			},
			{
				"$addFields": bson.M{
					"otherUserId": bson.M{
						"$cond": bson.M{
							"if":   bson.M{"$eq": bson.A{"$user1Id", userId}},
							"then": "$user2Id",
							"else": "$user1Id",
						},
					},
				},
			},
			{
				"$lookup": bson.M{
					"from":         "users",
					"localField":   "otherUserId",
					"foreignField": "_id",
					"as":           "otherUserData",
				},
			},
			{
				"$unwind": bson.M{
					"path":                       "$otherUserData",
					"preserveNullAndEmptyArrays": true,
				},
			},
			{
				"$project": bson.M{
					"roomId":        1,
					"otherUserId":   1,
					"username":      "$otherUserData.username",
					"avatarUrl":     "$otherUserData.avatarUrl",
					"movieName":     1,
					"posterUrl":     1,
					"status":        1,
					"unmatchedBy":   1,
					"lastMessage":   bson.M{"$arrayElemAt": bson.A{"$lastMessageData.content", 0}},
					"lastTimestamp": bson.M{"$arrayElemAt": bson.A{"$lastMessageData.timestamp", 0}},
					"unreadCount":   bson.M{"$arrayElemAt": bson.A{"$unreadData.count", 0}},
				},
			},
			{"$sort": bson.M{"lastTimestamp": -1}},
		}

		cursor, err := roomsCol.Aggregate(ctx, pipeline)
		if err != nil {
			log.Printf("⚠️ GetChatRoomsOptimized aggregation failed: %v", err)
			// Fallback to regular function
			GetChatRooms()(c)
			return
		}
		defer cursor.Close(ctx)

		var rooms []bson.M
		if err := cursor.All(ctx, &rooms); err != nil {
			log.Printf("⚠️ GetChatRoomsOptimized cursor.All failed: %v", err)
			GetChatRooms()(c)
			return
		}

		if len(rooms) == 0 {
			c.JSON(http.StatusOK, []map[string]interface{}{})
			return
		}

		result := make([]map[string]interface{}, 0, len(rooms))
		for _, room := range rooms {
			unreadCount := int64(0)
			if uc, ok := room["unreadCount"].(int32); ok {
				unreadCount = int64(uc)
			}

			otherUserId, _ := room["otherUserId"].(string)
			username, _ := room["username"].(string)
			avatarUrl, _ := room["avatarUrl"].(string)
			movieName, _ := room["movieName"].(string)
			posterUrl, _ := room["posterUrl"].(string)
			status, _ := room["status"].(string)
			unmatchedBy, _ := room["unmatchedBy"].(string)
			lastMessage, _ := room["lastMessage"].(string)
			lastTimestamp, _ := room["lastTimestamp"].(int64)

			entry := map[string]interface{}{
				"roomId":        room["roomId"],
				"targetUserId":  otherUserId,
				"username":      username,
				"avatarSeed":    otherUserId,
				"avatarUrl":     avatarUrl,
				"movieTitle":    movieName,
				"moviePoster":   posterUrl,
				"unreadCount":   unreadCount,
				"lastMessage":   lastMessage,
				"lastTimestamp": lastTimestamp,
				"status":        status,
				"unmatchedBy":   unmatchedBy,
			}
			result = append(result, entry)
		}

		log.Printf("🔎 GetChatRoomsOptimized success: userId=%s rooms=%d", userId, len(result))
		c.JSON(http.StatusOK, result)
	}
}

// GetChatMessagesPaginated — Limit ve cursor-based pagination destekli versiyon
// Bu fonksiyon tüm mesajları çekmek yerine sayfalama yapar
func GetChatMessagesPaginated() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
		defer cancel()

		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		roomID := c.Param("roomId")
		if strings.TrimSpace(roomID) == "" {
			errorResponse(c, http.StatusBadRequest, "INVALID_ROOM_ID", "Geçerli bir roomId gerekli", nil)
			return
		}

		// Pagination parametreleri
		limitStr := c.DefaultQuery("limit", "50")
		limit, err := strconv.Atoi(limitStr)
		if err != nil || limit <= 0 {
			limit = 50
		}
		if limit > 100 {
			limit = 100 // Max limit
		}

		// Cursor (timestamp bazlı)
		cursorStr := c.Query("cursor")
		var cursorTimestamp int64 = 0
		if cursorStr != "" {
			cursorTimestamp, err = strconv.ParseInt(cursorStr, 10, 64)
			if err != nil {
				cursorTimestamp = 0
			}
		}

		roomsCol := config.GetCollection(config.DB, "chatrooms")
		msgsCol := config.GetCollection(config.DB, "messages")

		// Oda yetkisi kontrolü
		var room struct {
			User1ID string `bson:"user1Id"`
			User2ID string `bson:"user2Id"`
		}
		err = roomsCol.FindOne(ctx, bson.M{
			"roomId": roomID,
			"$or": bson.A{
				bson.M{"user1Id": userId},
				bson.M{"user2Id": userId},
			},
		}).Decode(&room)
		if err != nil {
			errorResponse(c, http.StatusForbidden, "FORBIDDEN", "Bu odaya erişim yetkiniz yok", nil)
			return
		}

		// Filtre oluştur
		msgFilter := bson.M{
			"roomId": roomID,
			"type":   "message",
		}

		// Cursor varsa sadece ondan sonraki mesajları al (eskiden yeniye)
		if cursorTimestamp > 0 {
			msgFilter["timestamp"] = bson.M{"$lt": cursorTimestamp}
		}

		// Gizleme kontrolü
		hiddenKey := "chat:hidden:" + userId
		if tsStr, err := config.RedisClient.HGet(ctx, hiddenKey, roomID).Result(); err == nil {
			if hideTS, parseErr := strconv.ParseInt(tsStr, 10, 64); parseErr == nil && hideTS > 0 {
				msgFilter["timestamp"] = bson.M{"$gt": hideTS}
			}
		}

		// Sorgu seçenekleri: sıralı, limitli
		findOpts := options.Find().
			SetSort(bson.D{{Key: "timestamp", Value: -1}}).
			SetLimit(int64(limit))

		cursor, err := msgsCol.Find(ctx, msgFilter, findOpts)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "MESSAGES_QUERY_FAILED", "Mesajlar alınamadı", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var messages []map[string]interface{}
		var lastTimestamp int64 = 0

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

			if msg.Timestamp > lastTimestamp {
				lastTimestamp = msg.Timestamp
			}
		}

		if messages == nil {
			messages = []map[string]interface{}{}
		}

		// Sonraki sayfa için cursor döndür
		response := map[string]interface{}{
			"messages": messages,
			"hasMore":  len(messages) == limit,
		}

		// Cursor bilgisi (en eski mesajın timestamp'i)
		if len(messages) > 0 {
			oldestMsg := messages[len(messages)-1]
			if oldestTimestamp, ok := oldestMsg["timestamp"].(int64); ok {
				response["nextCursor"] = oldestTimestamp
			}
		}

		log.Printf("🔎 GetChatMessagesPaginated: roomId=%s userId=%s count=%d limit=%d cursor=%d",
			roomID, userId, len(messages), limit, cursorTimestamp)

		c.JSON(http.StatusOK, response)
	}
}
