package controllers

import (
	"context"
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// CreateList — Yeni bir liste (Kategori) oluşturur
func CreateList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		var input models.CreateListInput

		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Hatalı girdi: " + err.Error()})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		newList := models.List{
			UserID:      userId,
			Name:        input.Name,
			Description: input.Description,
			IsPublic:    input.IsPublic,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		}

		collection := config.GetCollection(config.DB, "lists")
		result, err := collection.InsertOne(ctx, newList)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Liste oluşturulamadı"})
			return
		}

		c.JSON(http.StatusCreated, gin.H{"message": "Liste başarıyla oluşturuldu", "listId": result.InsertedID})
	}
}

// GetMyLists — Kullanıcının oluşturduğu tüm listeleri (kategorileri) getirir
func GetMyLists() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		collection := config.GetCollection(config.DB, "lists")
		cursor, err := collection.Find(ctx, bson.M{"userId": userId})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Listeler getirilemedi"})
			return
		}
		defer cursor.Close(ctx)

		var lists []models.List
		if err = cursor.All(ctx, &lists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Listeler okunamadı"})
			return
		}

		c.JSON(http.StatusOK, lists)
	}
}

// AddMovieToList — Belirli bir listeye film ekler
func AddMovieToList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		var input models.AddToListInput

		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Hatalı girdi: " + err.Error()})
			return
		}

		listObjId, err := primitive.ObjectIDFromHex(input.ListID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz Liste ID'si"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		// 1. Listenin bu kullanıcıya ait olup olmadığını kontrol et
		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		err = listColl.FindOne(ctx, bson.M{"_id": listObjId, "userId": userId}).Decode(&list)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu liste bulunamadı veya size ait değil"})
			return
		}

		// 2. Film zaten bu listede var mı kontrol et
		itemColl := config.GetCollection(config.DB, "list_items")
		count, _ := itemColl.CountDocuments(ctx, bson.M{"listId": listObjId, "tmdbId": input.TmdbID})
		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "Bu film zaten bu listede mevcut"})
			return
		}

		// 3. Filmi ekle
		newItem := models.ListItem{
			ListID:    listObjId,
			TmdbID:    input.TmdbID,
			MovieName: input.MovieName,
			PosterURL: input.PosterURL,
			AddedAt:   time.Now(),
		}

		_, err = itemColl.InsertOne(ctx, newItem)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Film listeye eklenemedi"})
			return
		}

		// Listenin Update tarihini güncelle
		listColl.UpdateOne(ctx, bson.M{"_id": listObjId}, bson.M{"$set": bson.M{"updatedAt": time.Now()}})

		c.JSON(http.StatusOK, gin.H{"message": "Film başarıyla eklendi!"})
	}
}

// GetListItems — Bir listenin içindeki tüm filmleri getirir
func GetListItems() gin.HandlerFunc {
	return func(c *gin.Context) {
		listIdStr := c.Param("id")

		listObjId, err := primitive.ObjectIDFromHex(listIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz Liste ID'si"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		itemColl := config.GetCollection(config.DB, "list_items")
		cursor, err := itemColl.Find(ctx, bson.M{"listId": listObjId})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Filmler getirilemedi"})
			return
		}
		defer cursor.Close(ctx)

		var items []models.ListItem
		if err = cursor.All(ctx, &items); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Filmler okunamadı"})
			return
		}

		c.JSON(http.StatusOK, items)
	}
}
