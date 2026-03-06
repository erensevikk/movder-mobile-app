package controllers

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"log"
	"movder-backend/config"
	"movder-backend/models"
	"movder-backend/services"
	"net/http"
	"net/url"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

const (
	maxImportUploadBytes = 10 << 20 // 10MB
	maxZipEntries        = 50
	maxZipCSVFiles       = 20
	maxZipUnpackedBytes  = 40 << 20 // 40MB
	maxCSVRows           = 5000
	previewTTL           = 30 * time.Minute
	parseTimeout         = 12 * time.Second
	importRequestTimeout = 45 * time.Second
)

type parsedListItem struct {
	Position    int
	Name        string
	Year        int
	URL         string
	Description string
	TmdbID      int
	MovieName   string
	PosterURL   string
	Confidence  string
	Reason      string
}

type parsedList struct {
	Name        string
	Description string
	CreatedAt   time.Time
	Items       []parsedListItem
}

type importPreviewData struct {
	UserID    string
	Lists     []parsedList
	CreatedAt time.Time
}

type importCommitInput struct {
	PreviewToken string `json:"previewToken" binding:"required"`
	Strategy     string `json:"strategy"`
}

type previewUnresolvedItem struct {
	ListName string `json:"listName"`
	Position int    `json:"position"`
	Name     string `json:"name"`
	Year     int    `json:"year"`
	URL      string `json:"url"`
	Reason   string `json:"reason"`
}

type previewConflictCandidate struct {
	ListName          string `json:"listName"`
	ExistingListID    string `json:"existingListId"`
	ExistingItemCount int64  `json:"existingItemCount"`
	IncomingItemCount int    `json:"incomingItemCount"`
}

var searchMoviesFn = services.SearchMovies

var (
	importPreviewStore   = map[string]importPreviewData{}
	importPreviewStoreMu sync.Mutex
)

// CreateList â€” Yeni bir liste (Kategori) oluÅŸturur
func CreateList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		var input models.CreateListInput

		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "HatalÄ± girdi: " + err.Error()})
			return
		}

		input.Name = strings.TrimSpace(input.Name)
		nameRegex := regexp.MustCompile(`^[a-zA-ZğüşıöçĞÜŞİÖÇ\s]+$`)
		if !nameRegex.MatchString(input.Name) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Koleksiyon adı sadece harflerden oluşabilir."})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		collection := config.GetCollection(config.DB, "lists")

		var existing models.List
		// Case-insensitive check for duplicate name
		err := collection.FindOne(ctx, bson.M{
			"userId": userId,
			"name":   bson.M{"$regex": primitive.Regex{Pattern: "^" + regexp.QuoteMeta(input.Name) + "$", Options: "i"}},
		}).Decode(&existing)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Bu isimde bir koleksiyonunuz zaten mevcut."})
			return
		}

		newList := models.List{
			UserID:      userId,
			Name:        input.Name,
			Description: input.Description,
			IsPublic:    input.IsPublic,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		}

		result, err := collection.InsertOne(ctx, newList)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Liste oluÅŸturulamadÄ±"})
			return
		}

		c.JSON(http.StatusCreated, gin.H{"message": "Liste baÅŸarÄ±yla oluÅŸturuldu", "listId": result.InsertedID})
	}
}

// GetMyLists â€” KullanÄ±cÄ±nÄ±n oluÅŸturduÄŸu tÃ¼m listeleri (kategorileri) getirir
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
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Listeler okunamadÄ±"})
			return
		}

		c.JSON(http.StatusOK, lists)
	}
}

// GetUserLists — Belirli bir kullanıcının herkese açık listelerini (kategorilerini) getirir
func GetUserLists() gin.HandlerFunc {
	return func(c *gin.Context) {
		viewerIDHex := c.GetString("userId")
		targetUserId := c.Param("userId")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		collection := config.GetCollection(config.DB, "lists")
		userCollection := config.GetCollection(config.DB, "users")

		viewerID, err := primitive.ObjectIDFromHex(viewerIDHex)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği"})
			return
		}
		targetID, err := primitive.ObjectIDFromHex(targetUserId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz hedef kullanıcı kimliği"})
			return
		}

		var target models.User
		if err := userCollection.FindOne(ctx, bson.M{"_id": targetID}).Decode(&target); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
			return
		}

		isOwner := viewerIDHex == targetUserId
		isFriend := containsObjectID(target.Friends, viewerID)
		privacy := userPrivacySettings(target)
		canSeeDetails := canViewerSeeProfileDetails(viewerID, targetID, isFriend, privacy)
		if !isOwner && !canSeeDetails {
			c.JSON(http.StatusOK, []models.List{})
			return
		}

		filter := bson.M{"userId": targetUserId}
		if !isOwner && privacy.ProfileVisibility == "public" {
			filter["isPublic"] = true
		}

		cursor, err := collection.Find(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcının listeleri getirilemedi"})
			return
		}
		defer cursor.Close(ctx)

		var lists []models.List
		if err = cursor.All(ctx, &lists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcının listeleri okunamadı"})
			return
		}

		c.JSON(http.StatusOK, lists)
	}
}

// AddMovieToList â€” Belirli bir listeye film ekler
func AddMovieToList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		var input models.AddToListInput

		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "HatalÄ± girdi: " + err.Error()})
			return
		}

		listObjId, err := primitive.ObjectIDFromHex(input.ListID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "GeÃ§ersiz Liste ID'si"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		err = listColl.FindOne(ctx, bson.M{"_id": listObjId, "userId": userId}).Decode(&list)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu liste bulunamadÄ± veya size ait deÄŸil"})
			return
		}

		itemColl := config.GetCollection(config.DB, "list_items")
		count, _ := itemColl.CountDocuments(ctx, bson.M{"listId": listObjId, "tmdbId": input.TmdbID})
		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "Bu film zaten bu listede mevcut"})
			return
		}

		newItem := models.ListItem{
			ListID:    listObjId,
			Position:  input.Position,
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

		_, _ = listColl.UpdateOne(ctx, bson.M{"_id": listObjId}, bson.M{"$set": bson.M{"updatedAt": time.Now()}})
		c.JSON(http.StatusOK, gin.H{"message": "Film baÅŸarÄ±yla eklendi!"})
	}
}

// GetListItems â€” Bir listenin iÃ§indeki tÃ¼m filmleri getirir
func GetListItems() gin.HandlerFunc {
	return func(c *gin.Context) {
		viewerIDHex := c.GetString("userId")
		listIdStr := c.Param("listId")
		listObjId, err := primitive.ObjectIDFromHex(listIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "GeÃ§ersiz Liste ID'si"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		if err := listColl.FindOne(ctx, bson.M{"_id": listObjId}).Decode(&list); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Liste bulunamadı"})
			return
		}

		if list.UserID != viewerIDHex {
			userCollection := config.GetCollection(config.DB, "users")
			viewerID, err := primitive.ObjectIDFromHex(viewerIDHex)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz kullanıcı kimliği"})
				return
			}
			targetID, err := primitive.ObjectIDFromHex(list.UserID)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz liste sahibi kimliği"})
				return
			}

			var target models.User
			if err := userCollection.FindOne(ctx, bson.M{"_id": targetID}).Decode(&target); err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "Liste sahibi bulunamadı"})
				return
			}

			isFriend := containsObjectID(target.Friends, viewerID)
			privacy := userPrivacySettings(target)
			canSeeDetails := canViewerSeeProfileDetails(viewerID, targetID, isFriend, privacy)
			if !canSeeDetails || (privacy.ProfileVisibility == "public" && !list.IsPublic) {
				c.JSON(http.StatusForbidden, gin.H{"error": "Bu listeyi görme yetkiniz yok"})
				return
			}
		}

		itemColl := config.GetCollection(config.DB, "list_items")
		findOpts := options.Find().SetSort(bson.D{{Key: "position", Value: 1}, {Key: "addedAt", Value: 1}})
		cursor, err := itemColl.Find(ctx, bson.M{"listId": listObjId}, findOpts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Filmler getirilemedi"})
			return
		}
		defer cursor.Close(ctx)

		var items []models.ListItem
		if err = cursor.All(ctx, &items); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Filmler okunamadÄ±"})
			return
		}

		c.JSON(http.StatusOK, items)
	}
}

// RemoveMovieFromList — Belirli bir listeden film siler
func RemoveMovieFromList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		listIdStr := c.Param("listId")
		tmdbIdStr := c.Param("tmdbId")

		listObjId, err := primitive.ObjectIDFromHex(listIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz Liste ID'si"})
			return
		}

		tmdbId, err := strconv.Atoi(tmdbIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz Film ID'si"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		err = listColl.FindOne(ctx, bson.M{"_id": listObjId, "userId": userId}).Decode(&list)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu liste bulunamadı veya size ait değil"})
			return
		}

		itemColl := config.GetCollection(config.DB, "list_items")

		res, err := itemColl.DeleteOne(ctx, bson.M{"listId": listObjId, "tmdbId": tmdbId})
		if err != nil || res.DeletedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Film bu listede bulunamadı"})
			return
		}

		_, _ = listColl.UpdateOne(ctx, bson.M{"_id": listObjId}, bson.M{"$set": bson.M{"updatedAt": time.Now()}})
		c.JSON(http.StatusOK, gin.H{"message": "Film başarıyla silindi!"})
	}
}

// DeleteList — Bir listeyi ve içindeki tüm filmleri siler
func DeleteList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		listIdStr := c.Param("listId")

		listObjId, err := primitive.ObjectIDFromHex(listIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz Liste ID'si"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")

		// Listenin sahibi bu kullanıcı mı kontrol et
		var list models.List
		err = listColl.FindOne(ctx, bson.M{"_id": listObjId, "userId": userId}).Decode(&list)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu liste bulunamadı veya size ait değil"})
			return
		}

		// Önce listedeki tüm öğeleri sil
		itemColl := config.GetCollection(config.DB, "list_items")
		_, _ = itemColl.DeleteMany(ctx, bson.M{"listId": listObjId})

		// Sonra listeyi sil
		_, err = listColl.DeleteOne(ctx, bson.M{"_id": listObjId})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Liste silinemedi"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Liste başarıyla silindi!"})
	}
}

// RenameList — Bir listenin adını değiştirir
func RenameList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		listIdStr := c.Param("listId")

		listObjId, err := primitive.ObjectIDFromHex(listIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz Liste ID'si"})
			return
		}

		var input struct {
			Name string `json:"name" binding:"required"`
		}
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Yeni isim gerekli"})
			return
		}

		input.Name = strings.TrimSpace(input.Name)
		if input.Name == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Liste adı boş olamaz"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")

		// Listenin sahibi bu kullanıcı mı kontrol et
		var list models.List
		err = listColl.FindOne(ctx, bson.M{"_id": listObjId, "userId": userId}).Decode(&list)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu liste bulunamadı veya size ait değil"})
			return
		}

		// Aynı isimde başka liste var mı kontrol et
		nameRegex := primitive.Regex{Pattern: "^" + regexp.QuoteMeta(input.Name) + "$", Options: "i"}
		var existing models.List
		err = listColl.FindOne(ctx, bson.M{
			"userId": userId,
			"name":   bson.M{"$regex": nameRegex},
			"_id":    bson.M{"$ne": listObjId},
		}).Decode(&existing)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Bu isimde bir listeniz zaten var"})
			return
		}

		_, err = listColl.UpdateOne(ctx, bson.M{"_id": listObjId}, bson.M{
			"$set": bson.M{"name": input.Name, "updatedAt": time.Now()},
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Liste adı güncellenemedi"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Liste adı güncellendi!", "name": input.Name})
	}
}

// ReorderList — Listedeki filmlerin sırasını günceller
// Body: { "tmdbIds": [38, 19404, 694, ...] } — yeni sıradaki tmdbId dizisi
func ReorderList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.GetString("userId")
		listIdStr := c.Param("listId")

		listObjId, err := primitive.ObjectIDFromHex(listIdStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz Liste ID'si"})
			return
		}

		var input struct {
			TmdbIds []int `json:"tmdbIds" binding:"required"`
		}
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "tmdbIds dizisi gerekli"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")

		// Listenin sahibi kontrol et
		var list models.List
		if err = listColl.FindOne(ctx, bson.M{"_id": listObjId, "userId": userId}).Decode(&list); err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu liste bulunamadı veya size ait değil"})
			return
		}

		itemColl := config.GetCollection(config.DB, "list_items")

		// Her tmdbId'nin position'ını yeni index olarak güncelle
		for i, tmdbId := range input.TmdbIds {
			_, _ = itemColl.UpdateOne(ctx,
				bson.M{"listId": listObjId, "tmdbId": tmdbId},
				bson.M{"$set": bson.M{"position": i + 1}},
			)
		}

		c.JSON(http.StatusOK, gin.H{"message": "Sıralama güncellendi"})
	}
}

// PreviewLetterboxdImport — ZIP/CSV import Ã¶nizlemesi Ã¼retir, DB yazmaz
func PreviewLetterboxdImport() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isLetterboxdImportEnabled() {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error":     "Letterboxd import ozelligi su anda kapali",
				"errorCode": "IMPORT_DISABLED",
			})
			return
		}

		userID := c.GetString("userId")
		fileHeader, err := c.FormFile("file")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Yuklenecek dosya bulunamadi", "errorCode": "FILE_REQUIRED"})
			return
		}

		f, err := fileHeader.Open()
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dosya acilamadi", "errorCode": "FILE_OPEN_FAILED"})
			return
		}
		defer f.Close()

		payload, err := io.ReadAll(io.LimitReader(f, maxImportUploadBytes+1))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dosya okunamadi", "errorCode": "FILE_READ_FAILED"})
			return
		}
		if len(payload) > maxImportUploadBytes {
			c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "Dosya cok buyuk (max 10MB)", "errorCode": "UPLOAD_TOO_LARGE"})
			return
		}

		type parseResult struct {
			lists    []parsedList
			warnings []string
			err      error
		}
		parseCh := make(chan parseResult, 1)
		go func() {
			lists, warnings, err := parseLetterboxdPayload(payload, fileHeader.Filename)
			parseCh <- parseResult{lists: lists, warnings: warnings, err: err}
		}()

		var lists []parsedList
		var warnings []string
		select {
		case res := <-parseCh:
			lists, warnings, err = res.lists, res.warnings, res.err
		case <-time.After(parseTimeout):
			c.JSON(http.StatusRequestTimeout, gin.H{"error": "Dosya parse zaman asimina ugradi", "errorCode": "PARSE_TIMEOUT"})
			return
		}

		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error(), "errorCode": "PARSE_FAILED"})
			return
		}
		if len(lists) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dosyada import edilecek liste bulunamadi", "errorCode": "NO_LIST_FOUND"})
			return
		}

		unresolvedTotal := 0
		unresolvedItems := make([]previewUnresolvedItem, 0)
		for li := range lists {
			for ii := range lists[li].Items {
				matchTMDBMovie(&lists[li].Items[ii])
				if lists[li].Items[ii].TmdbID == 0 {
					unresolvedTotal++
					unresolvedItems = append(unresolvedItems, previewUnresolvedItem{
						ListName: lists[li].Name,
						Position: lists[li].Items[ii].Position,
						Name:     lists[li].Items[ii].Name,
						Year:     lists[li].Items[ii].Year,
						URL:      lists[li].Items[ii].URL,
						Reason:   lists[li].Items[ii].Reason,
					})
				}
			}
		}

		ctx, cancel := context.WithTimeout(context.Background(), importRequestTimeout)
		defer cancel()
		conflicts := detectConflictCandidates(ctx, userID, lists)

		token := primitive.NewObjectID().Hex()
		importPreviewStoreMu.Lock()
		importPreviewStore[token] = importPreviewData{UserID: userID, Lists: lists, CreatedAt: time.Now()}
		importPreviewStoreMu.Unlock()

		responseLists := make([]gin.H, 0, len(lists))
		for _, l := range lists {
			resolved := 0
			for _, it := range l.Items {
				if it.TmdbID > 0 {
					resolved++
				}
			}
			responseLists = append(responseLists, gin.H{
				"name":        l.Name,
				"description": l.Description,
				"createdAt":   l.CreatedAt,
				"itemCount":   len(l.Items),
				"resolved":    resolved,
				"unresolved":  len(l.Items) - resolved,
			})
		}

		c.JSON(http.StatusOK, gin.H{
			"previewToken": token,
			"lists":        responseLists,
			"warnings":     warnings,
			"warningsSummary": gin.H{
				"warningCount": len(warnings),
			},
			"unresolvedItems": unresolvedItems,
			"conflicts":       conflicts,
			"totals": gin.H{
				"listCount":       len(lists),
				"itemCount":       totalItems(lists),
				"unresolvedCount": unresolvedTotal,
				"conflictCount":   len(conflicts),
			},
		})
	}
}

// CommitLetterboxdImport â€” Ã¶nizlenen importu DB'ye yazar
func CommitLetterboxdImport() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isLetterboxdImportEnabled() {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error":     "Letterboxd import ozelligi su anda kapali",
				"errorCode": "IMPORT_DISABLED",
			})
			return
		}

		userID := c.GetString("userId")
		var input importCommitInput
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Gecersiz istek govdesi", "errorCode": "INVALID_BODY"})
			return
		}

		strategy := strings.ToLower(strings.TrimSpace(input.Strategy))
		if strategy == "" {
			strategy = "merge"
		}
		if strategy != "merge" && strategy != "overwrite" && strategy != "duplicate" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Gecersiz strategy: merge | overwrite | duplicate", "errorCode": "INVALID_STRATEGY"})
			return
		}

		importPreviewStoreMu.Lock()
		preview, ok := importPreviewStore[input.PreviewToken]
		if ok {
			delete(importPreviewStore, input.PreviewToken)
		}
		importPreviewStoreMu.Unlock()

		if !ok {
			c.JSON(http.StatusNotFound, gin.H{"error": "Preview bulunamadi veya suresi doldu", "errorCode": "PREVIEW_NOT_FOUND"})
			return
		}
		if preview.UserID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Bu preview size ait degil", "errorCode": "PREVIEW_FORBIDDEN"})
			return
		}
		if time.Since(preview.CreatedAt) > previewTTL {
			c.JSON(http.StatusGone, gin.H{"error": "Preview suresi doldu", "errorCode": "PREVIEW_EXPIRED"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), importRequestTimeout)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		itemColl := config.GetCollection(config.DB, "list_items")

		createdLists := 0
		updatedLists := 0
		addedItems := 0
		skippedDuplicates := 0
		skippedUnresolved := 0

		skippedUnresolvedDetails := make([]gin.H, 0)
		skippedDuplicateDetails := make([]gin.H, 0)

		for _, incoming := range preview.Lists {
			listID, existed, err := resolveTargetList(ctx, listColl, itemColl, userID, incoming, strategy)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Liste yazilirken hata olustu", "errorCode": "LIST_WRITE_FAILED"})
				return
			}
			if existed {
				updatedLists++
			} else {
				createdLists++
			}

			for _, item := range incoming.Items {
				if item.TmdbID == 0 {
					skippedUnresolved++
					skippedUnresolvedDetails = append(skippedUnresolvedDetails, gin.H{
						"listName": incoming.Name,
						"position": item.Position,
						"name":     item.Name,
						"year":     item.Year,
						"url":      item.URL,
						"reason":   item.Reason,
					})
					continue
				}

				if strategy != "overwrite" {
					cnt, _ := itemColl.CountDocuments(ctx, bson.M{"listId": listID, "tmdbId": item.TmdbID})
					if cnt > 0 {
						skippedDuplicates++
						skippedDuplicateDetails = append(skippedDuplicateDetails, gin.H{
							"listName":  incoming.Name,
							"position":  item.Position,
							"tmdbId":    item.TmdbID,
							"movieName": item.MovieName,
						})
						continue
					}
				}

				_, err = itemColl.InsertOne(ctx, models.ListItem{
					ListID:    listID,
					Position:  item.Position,
					TmdbID:    item.TmdbID,
					MovieName: item.MovieName,
					PosterURL: item.PosterURL,
					AddedAt:   time.Now(),
				})
				if err == nil {
					addedItems++
				}
			}

			_, _ = listColl.UpdateOne(ctx, bson.M{"_id": listID}, bson.M{"$set": bson.M{"updatedAt": time.Now()}})
		}

		// Import başarılı — kullanıcıyı işaretleyelim
		userIDObj, _ := primitive.ObjectIDFromHex(userID)
		userColl := config.GetCollection(config.DB, "users")
		_, _ = userColl.UpdateOne(ctx, bson.M{"_id": userIDObj}, bson.M{"$set": bson.M{"letterboxd_imported": true}})

		c.JSON(http.StatusOK, gin.H{
			"message": "Letterboxd import tamamlandi",
			"summary": gin.H{
				"createdLists":      createdLists,
				"updatedLists":      updatedLists,
				"addedItems":        addedItems,
				"skippedDuplicates": skippedDuplicates,
				"skippedUnresolved": skippedUnresolved,
			},
			"skipped": gin.H{
				"unresolved": skippedUnresolvedDetails,
				"duplicates": skippedDuplicateDetails,
			},
		})
	}
}
func resolveTargetList(
	ctx context.Context,
	listColl *mongo.Collection,
	itemColl *mongo.Collection,
	userID string,
	incoming parsedList,
	strategy string,
) (primitive.ObjectID, bool, error) {
	var existing models.List
	err := listColl.FindOne(ctx, bson.M{"userId": userID, "name": incoming.Name}).Decode(&existing)
	if err != nil && err != mongo.ErrNoDocuments {
		return primitive.NilObjectID, false, err
	}

	now := time.Now()
	if err == mongo.ErrNoDocuments {
		res, insertErr := listColl.InsertOne(ctx, models.List{
			UserID:      userID,
			Name:        incoming.Name,
			Description: incoming.Description,
			IsPublic:    true,
			CreatedAt:   incoming.CreatedAt,
			UpdatedAt:   now,
		})
		if insertErr != nil {
			return primitive.NilObjectID, false, insertErr
		}
		id, ok := res.InsertedID.(primitive.ObjectID)
		if !ok {
			return primitive.NilObjectID, false, errors.New("liste ID oluÅŸturulamadÄ±")
		}
		return id, false, nil
	}

	if strategy == "duplicate" {
		dupName := incoming.Name
		i := 2
		for {
			candidate := fmt.Sprintf("%s (%d)", incoming.Name, i)
			cnt, countErr := listColl.CountDocuments(ctx, bson.M{"userId": userID, "name": candidate})
			if countErr != nil {
				return primitive.NilObjectID, false, countErr
			}
			if cnt == 0 {
				dupName = candidate
				break
			}
			i++
		}
		res, insertErr := listColl.InsertOne(ctx, models.List{
			UserID:      userID,
			Name:        dupName,
			Description: incoming.Description,
			IsPublic:    existing.IsPublic,
			CreatedAt:   incoming.CreatedAt,
			UpdatedAt:   now,
		})
		if insertErr != nil {
			return primitive.NilObjectID, false, insertErr
		}
		id, ok := res.InsertedID.(primitive.ObjectID)
		if !ok {
			return primitive.NilObjectID, false, errors.New("kopya liste ID oluÅŸturulamadÄ±")
		}
		return id, false, nil
	}

	_, updErr := listColl.UpdateOne(ctx, bson.M{"_id": existing.ID}, bson.M{"$set": bson.M{
		"description": incoming.Description,
		"updatedAt":   now,
	}})
	if updErr != nil {
		return primitive.NilObjectID, false, updErr
	}

	if strategy == "overwrite" {
		_, _ = itemColl.DeleteMany(ctx, bson.M{"listId": existing.ID})
	}

	return existing.ID, true, nil
}

func totalItems(lists []parsedList) int {
	t := 0
	for _, l := range lists {
		t += len(l.Items)
	}
	return t
}

func parseLetterboxdPayload(payload []byte, filename string) ([]parsedList, []string, error) {
	if isZipPayload(payload, filename) {
		return parseZipPayload(payload)
	}
	l, w, err := parseSingleCSVPayload(payload, filename)
	if err != nil {
		return nil, nil, err
	}
	return []parsedList{l}, w, nil
}

func isZipPayload(payload []byte, filename string) bool {
	if len(payload) >= 4 && bytes.Equal(payload[:4], []byte{'P', 'K', 3, 4}) {
		return true
	}
	return strings.EqualFold(filepath.Ext(filename), ".zip")
}

func parseZipPayload(payload []byte) ([]parsedList, []string, error) {
	zr, err := zip.NewReader(bytes.NewReader(payload), int64(len(payload)))
	if err != nil {
		return nil, nil, errors.New("ZIP acilamadi")
	}
	if len(zr.File) > maxZipEntries {
		return nil, nil, fmt.Errorf("ZIP icinde cok fazla dosya var (max %d)", maxZipEntries)
	}

	preferred := make([]*zip.File, 0)
	fallback := make([]*zip.File, 0)
	csvCount := 0
	var unpackedTotal uint64

	for _, f := range zr.File {
		if f.FileInfo().IsDir() {
			continue
		}

		clean := filepath.ToSlash(filepath.Clean(f.Name))
		if strings.Contains(clean, "../") || strings.HasPrefix(clean, "../") || strings.HasPrefix(clean, "/") {
			continue
		}

		unpackedTotal += f.UncompressedSize64
		if unpackedTotal > maxZipUnpackedBytes {
			return nil, nil, fmt.Errorf("ZIP acildiginda boyut limiti asiliyor (max %dMB)", maxZipUnpackedBytes>>20)
		}

		if !strings.HasSuffix(strings.ToLower(clean), ".csv") {
			continue
		}
		csvCount++
		if csvCount > maxZipCSVFiles {
			return nil, nil, fmt.Errorf("ZIP icinde cok fazla CSV var (max %d)", maxZipCSVFiles)
		}

		if strings.HasPrefix(strings.ToLower(clean), "lists/") {
			preferred = append(preferred, f)
		} else {
			fallback = append(fallback, f)
		}
	}

	csvFiles := preferred
	if len(csvFiles) == 0 {
		csvFiles = fallback
	}
	if len(csvFiles) == 0 {
		return nil, nil, errors.New("ZIP icinde CSV dosyasi bulunamadi")
	}

	log.Printf("[DEBUG-ZIP] preferred CSV dosyalari: %d, fallback CSV dosyalari: %d", len(preferred), len(fallback))
	for i, f := range preferred {
		log.Printf("[DEBUG-ZIP]   preferred[%d]: %s (size=%d)", i, f.Name, f.UncompressedSize64)
	}
	for i, f := range fallback {
		log.Printf("[DEBUG-ZIP]   fallback[%d]: %s (size=%d)", i, f.Name, f.UncompressedSize64)
	}

	lists := make([]parsedList, 0, len(csvFiles))
	warnings := make([]string, 0)
	for _, f := range csvFiles {
		log.Printf("[DEBUG-ZIP] CSV okunuyor: %s", f.Name)
		rc, err := f.Open()
		if err != nil {
			log.Printf("[DEBUG-ZIP] CSV acilamadi: %s err=%v", f.Name, err)
			warnings = append(warnings, "CSV acilamadi: "+f.Name)
			continue
		}

		content, err := io.ReadAll(io.LimitReader(rc, maxImportUploadBytes+1))
		_ = rc.Close()
		if err != nil {
			log.Printf("[DEBUG-ZIP] CSV okunamadi: %s err=%v", f.Name, err)
			warnings = append(warnings, "CSV okunamadi: "+f.Name)
			continue
		}
		if len(content) > maxImportUploadBytes {
			warnings = append(warnings, "CSV boyutu cok buyuk: "+f.Name)
			continue
		}

		log.Printf("[DEBUG-ZIP] CSV icerigi (ilk 500 byte): %s", string(content[:min(len(content), 500)]))

		parsed, warn, err := parseSingleCSVPayload(content, f.Name)
		if err != nil {
			log.Printf("[DEBUG-ZIP] CSV parse hatasi: %s err=%v", f.Name, err)
			warnings = append(warnings, fmt.Sprintf("%s: %s", f.Name, err.Error()))
			continue
		}
		log.Printf("[DEBUG-ZIP] CSV parse OK: %s -> liste=%q, item sayisi=%d", f.Name, parsed.Name, len(parsed.Items))
		for i, item := range parsed.Items {
			log.Printf("[DEBUG-ZIP]   item[%d]: pos=%d name=%q year=%d url=%q", i, item.Position, item.Name, item.Year, item.URL)
		}
		warnings = append(warnings, warn...)
		lists = append(lists, parsed)
	}

	return lists, warnings, nil
}

func parseSingleCSVPayload(payload []byte, filename string) (parsedList, []string, error) {
	reader := csv.NewReader(bytes.NewReader(payload))
	reader.FieldsPerRecord = -1
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	records, err := reader.ReadAll()
	if err != nil {
		return parsedList{}, nil, errors.New("CSV parse edilemedi")
	}
	if len(records) == 0 {
		return parsedList{}, nil, errors.New("CSV bos")
	}
	if len(records) > maxCSVRows {
		return parsedList{}, nil, fmt.Errorf("CSV satir limiti asildi (max %d)", maxCSVRows)
	}

	metaHeaderIdx := findRowByFirstCell(records, "Date")
	if metaHeaderIdx < 0 || metaHeaderIdx+1 >= len(records) {
		return parsedList{}, nil, errors.New("Liste metadata satiri bulunamadi")
	}
	meta := mapHeaderToValues(records[metaHeaderIdx], records[metaHeaderIdx+1])

	warnings := make([]string, 0)
	for _, key := range []string{"Date", "Name", "Description"} {
		if _, ok := meta[key]; !ok {
			warnings = append(warnings, "Metadata kolonu eksik: "+key)
		}
	}

	name := normalizeText(meta["Name"])
	if name == "" {
		name = strings.TrimSuffix(filepath.Base(filename), filepath.Ext(filename))
	}

	dateRaw := normalizeText(meta["Date"])
	result := parsedList{
		Name:        name,
		Description: normalizeText(meta["Description"]),
		CreatedAt:   parseLetterboxdDate(dateRaw),
		Items:       []parsedListItem{},
	}

	itemHeaderIdx := findRowByFirstCell(records, "Position")
	if itemHeaderIdx < 0 || itemHeaderIdx+1 >= len(records) {
		warnings = append(warnings, "Film satirlari bulunamadi")
		return result, warnings, nil
	}

	itemHeader := records[itemHeaderIdx]
	for _, key := range []string{"Position", "Name", "Year", "URL"} {
		if !headerContains(itemHeader, key) {
			warnings = append(warnings, "Film kolonu eksik: "+key)
		}
	}

	for i := itemHeaderIdx + 1; i < len(records); i++ {
		row := records[i]
		if isBlankRow(row) {
			continue
		}

		vals := mapHeaderToValues(itemHeader, row)
		movieName := normalizeText(vals["Name"])
		if movieName == "" {
			continue
		}

		position, _ := strconv.Atoi(normalizeText(vals["Position"]))
		year, _ := strconv.Atoi(normalizeText(vals["Year"]))
		result.Items = append(result.Items, parsedListItem{
			Position:    position,
			Name:        movieName,
			Year:        year,
			URL:         normalizeText(vals["URL"]),
			Description: normalizeText(vals["Description"]),
		})
	}

	return result, warnings, nil
}

func matchTMDBMovie(item *parsedListItem) {
	if item == nil {
		return
	}

	log.Printf("[DEBUG-TMDB] Eslestirme basliyor: name=%q year=%d url=%q", item.Name, item.Year, item.URL)

	source, picked, score := findBestTMDBCandidate(item)
	if picked == nil {
		log.Printf("[DEBUG-TMDB]   -> SONUC YOK (TMDB sonucu bulunamadi)")
		item.Confidence = "unresolved"
		item.Reason = "TMDB sonucu bulunamadi"
		return
	}

	log.Printf("[DEBUG-TMDB]   -> picked: id=%d title=%q original=%q score=%d source=%s", picked.ID, picked.Title, picked.OriginalTitle, score, source)

	item.Confidence = confidenceFromScore(score)
	log.Printf("[DEBUG-TMDB]   -> confidence=%s", item.Confidence)

	if item.Confidence == "unresolved" {
		item.TmdbID = 0
		item.MovieName = ""
		item.PosterURL = ""
		item.Reason = fmt.Sprintf("Dusuk eslesme skoru (%d)", score)
		log.Printf("[DEBUG-TMDB]   -> DUSUK SKOR, unresolved: %d", score)
		return
	}

	item.TmdbID = picked.ID
	item.MovieName = picked.Title
	item.Reason = ""
	if strings.TrimSpace(picked.PosterPath) != "" {
		item.PosterURL = "https://image.tmdb.org/t/p/w342" + picked.PosterPath
	}

	if source == "slug" && item.Confidence == "probable" && score >= 70 {
		item.Confidence = "exact"
	}
	log.Printf("[DEBUG-TMDB]   -> ESLESME OK: tmdbID=%d movieName=%q confidence=%s", item.TmdbID, item.MovieName, item.Confidence)
}

func findBestTMDBCandidate(item *parsedListItem) (string, *services.TMDBMovie, int) {
	type querySpec struct {
		source string
		query  string
		year   int // 0 = yılsız arama
		bonus  int
	}

	queries := make([]querySpec, 0, 3)

	// 1) Slug'dan isim + yıl (tam letterboxd.com/film/... URL'lerinde çalışır)
	if slugQuery := queryFromSlug(item.URL); slugQuery != "" {
		queries = append(queries, querySpec{source: "slug", query: slugQuery, year: item.Year, bonus: 15})
	}

	// 2) CSV'deki isim, yılı primary_release_year olarak geç (en doğru yöntem)
	if item.Year > 0 {
		queries = append(queries, querySpec{source: "title+year", query: item.Name, year: item.Year, bonus: 0})
	}

	// 3) Sadece isim — yıl eşleşmezse veya yıl yoksa fallback
	queries = append(queries, querySpec{source: "title_only", query: item.Name, year: 0, bonus: 0})

	bestScore := -1
	bestSource := ""
	var bestMovie *services.TMDBMovie

	for _, q := range queries {
		log.Printf("[DEBUG-TMDB]   query: source=%s q=%q year=%d", q.source, q.query, q.year)
		var (
			res *services.TMDBSearchResponse
			err error
		)
		if q.year > 0 {
			res, err = services.SearchMoviesWithYear(q.query, q.year)
		} else {
			res, err = searchMoviesFn(q.query)
		}
		if err != nil {
			log.Printf("[DEBUG-TMDB]   -> HATA: %v", err)
			continue
		}
		if res == nil || len(res.Results) == 0 {
			log.Printf("[DEBUG-TMDB]   -> BOS SONUC")
			continue
		}
		log.Printf("[DEBUG-TMDB]   -> %d sonuc geldi", len(res.Results))

		for i := range res.Results {
			m := res.Results[i]
			score := scoreTMDBCandidate(item, m, i) + q.bonus
			if score > bestScore {
				bestScore = score
				bestSource = q.source
				picked := m
				bestMovie = &picked
			}
		}

		// Mükemmel eşleşme — diğer sorgulara gerek yok
		if bestScore >= 90 {
			break
		}
	}

	return bestSource, bestMovie, bestScore
}

func scoreTMDBCandidate(item *parsedListItem, m services.TMDBMovie, idx int) int {
	score := 0
	titleA := strings.ToLower(strings.TrimSpace(item.Name))
	titleB := strings.ToLower(strings.TrimSpace(m.Title))
	originalB := strings.ToLower(strings.TrimSpace(m.OriginalTitle))

	// Hem çevrilmiş title hem original_title ile karşılaştır, en yüksek skoru al
	titleScore := 0
	switch {
	case titleA != "" && titleA == titleB:
		titleScore = 60
	case titleA != "" && (strings.Contains(titleB, titleA) || strings.Contains(titleA, titleB)):
		titleScore = 30
	}

	originalScore := 0
	switch {
	case titleA != "" && titleA == originalB:
		originalScore = 60
	case titleA != "" && (strings.Contains(originalB, titleA) || strings.Contains(titleA, originalB)):
		originalScore = 30
	}

	if originalScore > titleScore {
		score += originalScore
	} else {
		score += titleScore
	}

	y := parseYearFromRelease(m.ReleaseDate)
	if item.Year > 0 && y == item.Year {
		score += 35
	} else if item.Year > 0 && y != 0 {
		diff := y - item.Year
		if diff < 0 {
			diff = -diff
		}
		if diff == 1 {
			score += 10
		}
	}

	if idx == 0 {
		score += 5
	}

	return score
}

func confidenceFromScore(score int) string {
	if score >= 90 {
		return "exact"
	}
	if score >= 50 {
		return "probable"
	}
	return "unresolved"
}

func queryFromSlug(rawURL string) string {
	slug := extractLetterboxdSlug(rawURL)
	if slug == "" {
		return ""
	}
	clean := strings.ReplaceAll(slug, "-", " ")
	clean = strings.TrimSpace(clean)
	if clean == "" {
		return ""
	}
	return normalizeText(clean)
}

func extractLetterboxdSlug(rawURL string) string {
	u, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil || u == nil {
		return ""
	}
	parts := strings.Split(strings.Trim(u.Path, "/"), "/")
	for i := 0; i < len(parts)-1; i++ {
		if strings.EqualFold(parts[i], "film") {
			return strings.TrimSpace(parts[i+1])
		}
	}
	return ""
}

func parseYearFromRelease(releaseDate string) int {
	if len(releaseDate) < 4 {
		return 0
	}
	y, _ := strconv.Atoi(releaseDate[:4])
	return y
}

func parseLetterboxdDate(raw string) time.Time {
	raw = normalizeText(raw)
	if raw == "" {
		return time.Now()
	}
	layouts := []string{"2006-01-02", "02 Jan 2006", "2 Jan 2006", "Jan 2 2006", "2006/01/02", "02.01.2006"}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, raw); err == nil {
			return t
		}
	}
	return time.Now()
}

func detectConflictCandidates(ctx context.Context, userID string, lists []parsedList) []previewConflictCandidate {
	conflicts := make([]previewConflictCandidate, 0)
	listColl := config.GetCollection(config.DB, "lists")
	itemColl := config.GetCollection(config.DB, "list_items")

	for _, incoming := range lists {
		var existing models.List
		err := listColl.FindOne(ctx, bson.M{"userId": userID, "name": incoming.Name}).Decode(&existing)
		if err != nil {
			continue
		}

		itemCount, _ := itemColl.CountDocuments(ctx, bson.M{"listId": existing.ID})
		conflicts = append(conflicts, previewConflictCandidate{
			ListName:          incoming.Name,
			ExistingListID:    existing.ID.Hex(),
			ExistingItemCount: itemCount,
			IncomingItemCount: len(incoming.Items),
		})
	}

	sort.Slice(conflicts, func(i, j int) bool {
		return conflicts[i].ListName < conflicts[j].ListName
	})

	return conflicts
}

func isLetterboxdImportEnabled() bool {
	raw := strings.TrimSpace(strings.ToLower(config.GetEnv("FEATURE_LETTERBOXD_IMPORT", "false")))
	return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
}

func normalizeText(s string) string {
	s = strings.ToValidUTF8(s, "")
	s = strings.TrimSpace(strings.ReplaceAll(s, "\uFEFF", ""))
	s = strings.Map(func(r rune) rune {
		if r == '\n' || r == '\t' || r == '\r' {
			return r
		}
		if unicode.IsControl(r) {
			return -1
		}
		return r
	}, s)
	return strings.TrimSpace(s)
}

func findRowByFirstCell(records [][]string, firstCell string) int {
	for i, row := range records {
		if len(row) == 0 {
			continue
		}
		if strings.EqualFold(normalizeText(row[0]), firstCell) {
			return i
		}
	}
	return -1
}

func mapHeaderToValues(header []string, row []string) map[string]string {
	m := map[string]string{}
	for i := 0; i < len(header); i++ {
		k := normalizeText(header[i])
		if k == "" {
			continue
		}
		if i < len(row) {
			m[k] = normalizeText(row[i])
		} else {
			m[k] = ""
		}
	}
	return m
}

func headerContains(header []string, key string) bool {
	for _, col := range header {
		if strings.EqualFold(normalizeText(col), key) {
			return true
		}
	}
	return false
}

func isBlankRow(row []string) bool {
	for _, v := range row {
		if normalizeText(v) != "" {
			return false
		}
	}
	return true
}
