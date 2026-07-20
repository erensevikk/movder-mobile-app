package controllers

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
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
		userId, ok := mustUserID(c)
		if !ok {
			return
		}
		var input models.CreateListInput

		if err := c.ShouldBindJSON(&input); err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "Hatalı girdi", err.Error())
			return
		}

		input.Name = strings.TrimSpace(input.Name)
		nameRegex := regexp.MustCompile(`^[a-zA-ZğüşıöçĞÜŞİÖÇ\s]+$`)
		if !nameRegex.MatchString(input.Name) {
			errorResponse(c, http.StatusBadRequest, "INVALID_LIST_NAME", "Koleksiyon adı sadece harflerden oluşabilir.", nil)
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		collection := config.GetCollection(config.DB, "lists")

		var existing models.List
		// Case-insensitive check for duplicate name
		err := collection.FindOne(ctx, bson.M{
			"userId": userId,
			"name":   bson.M{"$regex": primitive.Regex{Pattern: "^" + regexp.QuoteMeta(input.Name) + "$", Options: "i"}},
		}).Decode(&existing)
		if err == nil {
			errorResponse(c, http.StatusConflict, "LIST_NAME_CONFLICT", "Bu isimde bir koleksiyonunuz zaten mevcut.", nil)
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
			errorResponse(c, http.StatusInternalServerError, "LIST_CREATE_FAILED", "Liste oluşturulamadı", err.Error())
			return
		}

		c.JSON(http.StatusCreated, gin.H{"message": "Liste baÅŸarÄ±yla oluÅŸturuldu", "listId": result.InsertedID})
	}
}

// GetMyLists â€” KullanÄ±cÄ±nÄ±n oluÅŸturduÄŸu tÃ¼m listeleri (kategorileri) getirir
func GetMyLists() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId, ok := mustUserID(c)
		if !ok {
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		collection := config.GetCollection(config.DB, "lists")
		cursor, err := collection.Find(ctx, bson.M{"userId": userId})
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "LISTS_QUERY_FAILED", "Listeler getirilemedi", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var lists []models.List
		if err = cursor.All(ctx, &lists); err != nil {
			errorResponse(c, http.StatusInternalServerError, "LISTS_READ_FAILED", "Listeler okunamadı", err.Error())
			return
		}

		c.JSON(http.StatusOK, lists)
	}
}

// GetUserLists — Belirli bir kullanıcının herkese açık listelerini (kategorilerini) getirir
func GetUserLists() gin.HandlerFunc {
	return func(c *gin.Context) {
		viewerIDHex, ok := mustUserID(c)
		if !ok {
			return
		}
		targetUserId := c.Param("userId")

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		collection := config.GetCollection(config.DB, "lists")
		userCollection := config.GetCollection(config.DB, "users")

		viewerID, ok := parseObjectIDOrBadRequest(c, viewerIDHex, "kullanıcı kimliği")
		if !ok {
			return
		}
		targetID, ok := parseObjectIDOrBadRequest(c, targetUserId, "hedef kullanıcı kimliği")
		if !ok {
			return
		}

		var target models.User
		if err := userCollection.FindOne(ctx, bson.M{"_id": targetID}).Decode(&target); err != nil {
			errorResponse(c, http.StatusNotFound, "USER_NOT_FOUND", "Kullanıcı bulunamadı", nil)
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
			errorResponse(c, http.StatusInternalServerError, "USER_LISTS_QUERY_FAILED", "Kullanıcının listeleri getirilemedi", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var lists []models.List
		if err = cursor.All(ctx, &lists); err != nil {
			errorResponse(c, http.StatusInternalServerError, "USER_LISTS_READ_FAILED", "Kullanıcının listeleri okunamadı", err.Error())
			return
		}

		c.JSON(http.StatusOK, lists)
	}
}

// AddMovieToList â€” Belirli bir listeye film ekler
func AddMovieToList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId, ok := mustUserID(c)
		if !ok {
			return
		}
		var input models.AddToListInput

		if err := c.ShouldBindJSON(&input); err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "Hatalı girdi", err.Error())
			return
		}

		listObjId, ok := parseObjectIDOrBadRequest(c, input.ListID, "liste kimliği")
		if !ok {
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		err := listColl.FindOne(ctx, bson.M{"_id": listObjId, "userId": userId}).Decode(&list)
		if err != nil {
			errorResponse(c, http.StatusForbidden, "LIST_FORBIDDEN", "Bu liste bulunamadı veya size ait değil", nil)
			return
		}

		itemColl := config.GetCollection(config.DB, "list_items")
		count, _ := itemColl.CountDocuments(ctx, bson.M{"listId": listObjId, "tmdbId": input.TmdbID})
		if count > 0 {
			errorResponse(c, http.StatusConflict, "LIST_ITEM_CONFLICT", "Bu film zaten bu listede mevcut", nil)
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
			errorResponse(c, http.StatusInternalServerError, "LIST_ITEM_CREATE_FAILED", "Film listeye eklenemedi", err.Error())
			return
		}

		_, _ = listColl.UpdateOne(ctx, bson.M{"_id": listObjId}, bson.M{"$set": bson.M{"updatedAt": time.Now()}})
		c.JSON(http.StatusOK, gin.H{"message": "Film başarıyla eklendi!"})
	}
}

// GetListItems â€” Bir listenin iÃ§indeki tÃ¼m filmleri getirir
func GetListItems() gin.HandlerFunc {
	return func(c *gin.Context) {
		viewerIDHex, ok := mustUserID(c)
		if !ok {
			return
		}
		listIdStr := c.Param("listId")
		listObjId, ok := parseObjectIDOrBadRequest(c, listIdStr, "liste kimliği")
		if !ok {
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		if err := listColl.FindOne(ctx, bson.M{"_id": listObjId}).Decode(&list); err != nil {
			errorResponse(c, http.StatusNotFound, "LIST_NOT_FOUND", "Liste bulunamadı", nil)
			return
		}

		if list.UserID != viewerIDHex {
			userCollection := config.GetCollection(config.DB, "users")
			viewerID, ok := parseObjectIDOrBadRequest(c, viewerIDHex, "kullanıcı kimliği")
			if !ok {
				return
			}
			targetID, ok := parseObjectIDOrBadRequest(c, list.UserID, "liste sahibi kimliği")
			if !ok {
				return
			}

			var target models.User
			if err := userCollection.FindOne(ctx, bson.M{"_id": targetID}).Decode(&target); err != nil {
				errorResponse(c, http.StatusNotFound, "LIST_OWNER_NOT_FOUND", "Liste sahibi bulunamadı", nil)
				return
			}

			isFriend := containsObjectID(target.Friends, viewerID)
			privacy := userPrivacySettings(target)
			canSeeDetails := canViewerSeeProfileDetails(viewerID, targetID, isFriend, privacy)
			if !canSeeDetails || (privacy.ProfileVisibility == "public" && !list.IsPublic) {
				errorResponse(c, http.StatusForbidden, "LIST_FORBIDDEN", "Bu listeyi görme yetkiniz yok", nil)
				return
			}
		}

		itemColl := config.GetCollection(config.DB, "list_items")
		findOpts := options.Find().SetSort(bson.D{{Key: "position", Value: 1}, {Key: "addedAt", Value: 1}})
		cursor, err := itemColl.Find(ctx, bson.M{"listId": listObjId}, findOpts)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "LIST_ITEMS_QUERY_FAILED", "Filmler getirilemedi", err.Error())
			return
		}
		defer cursor.Close(ctx)

		var items []models.ListItem
		if err = cursor.All(ctx, &items); err != nil {
			errorResponse(c, http.StatusInternalServerError, "LIST_ITEMS_READ_FAILED", "Filmler okunamadı", err.Error())
			return
		}

		c.JSON(http.StatusOK, items)
	}
}

// RemoveMovieFromList — Belirli bir listeden film siler
func RemoveMovieFromList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		listObjID, ok := parseObjectIDOrBadRequest(c, c.Param("listId"), "liste kimliği")
		if !ok {
			return
		}

		tmdbID, err := strconv.Atoi(c.Param("tmdbId"))
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_TMDB_ID", "Geçersiz film kimliği", nil)
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		err = listColl.FindOne(ctx, bson.M{"_id": listObjID, "userId": userID}).Decode(&list)
		if err != nil {
			errorResponse(c, http.StatusForbidden, "LIST_FORBIDDEN", "Bu liste bulunamadı veya size ait değil", nil)
			return
		}

		itemColl := config.GetCollection(config.DB, "list_items")
		res, err := itemColl.DeleteOne(ctx, bson.M{"listId": listObjID, "tmdbId": tmdbID})
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "LIST_ITEM_DELETE_FAILED", "Film listeden silinemedi", err.Error())
			return
		}
		if res.DeletedCount == 0 {
			errorResponse(c, http.StatusNotFound, "LIST_ITEM_NOT_FOUND", "Film bu listede bulunamadı", nil)
			return
		}

		_, _ = listColl.UpdateOne(ctx, bson.M{"_id": listObjID}, bson.M{"$set": bson.M{"updatedAt": time.Now()}})
		c.JSON(http.StatusOK, gin.H{"message": "Film başarıyla silindi!"})
	}
}

// DeleteList — Bir listeyi ve içindeki tüm filmleri siler
func DeleteList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		listObjID, ok := parseObjectIDOrBadRequest(c, c.Param("listId"), "liste kimliği")
		if !ok {
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")

		var list models.List
		err := listColl.FindOne(ctx, bson.M{"_id": listObjID, "userId": userID}).Decode(&list)
		if err != nil {
			errorResponse(c, http.StatusForbidden, "LIST_FORBIDDEN", "Bu liste bulunamadı veya size ait değil", nil)
			return
		}

		itemColl := config.GetCollection(config.DB, "list_items")
		_, _ = itemColl.DeleteMany(ctx, bson.M{"listId": listObjID})

		_, err = listColl.DeleteOne(ctx, bson.M{"_id": listObjID})
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "LIST_DELETE_FAILED", "Liste silinemedi", err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Liste başarıyla silindi!"})
	}
}

// RenameList — Bir listenin adını değiştirir
func RenameList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		listObjID, ok := parseObjectIDOrBadRequest(c, c.Param("listId"), "liste kimliği")
		if !ok {
			return
		}

		var input struct {
			Name string `json:"name" binding:"required"`
		}
		if err := c.ShouldBindJSON(&input); err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "Yeni isim gerekli", nil)
			return
		}

		input.Name = strings.TrimSpace(input.Name)
		if input.Name == "" {
			errorResponse(c, http.StatusBadRequest, "EMPTY_LIST_NAME", "Liste adı boş olamaz", nil)
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")

		var list models.List
		err := listColl.FindOne(ctx, bson.M{"_id": listObjID, "userId": userID}).Decode(&list)
		if err != nil {
			errorResponse(c, http.StatusForbidden, "LIST_FORBIDDEN", "Bu liste bulunamadı veya size ait değil", nil)
			return
		}

		nameRegex := primitive.Regex{Pattern: "^" + regexp.QuoteMeta(input.Name) + "$", Options: "i"}
		var existing models.List
		err = listColl.FindOne(ctx, bson.M{
			"userId": userID,
			"name":   bson.M{"$regex": nameRegex},
			"_id":    bson.M{"$ne": listObjID},
		}).Decode(&existing)
		if err == nil {
			errorResponse(c, http.StatusConflict, "LIST_NAME_CONFLICT", "Bu isimde bir listeniz zaten var", nil)
			return
		}
		if err != mongo.ErrNoDocuments {
			errorResponse(c, http.StatusInternalServerError, "LIST_LOOKUP_FAILED", "Liste doğrulanamadı", err.Error())
			return
		}

		_, err = listColl.UpdateOne(ctx, bson.M{"_id": listObjID}, bson.M{
			"$set": bson.M{"name": input.Name, "updatedAt": time.Now()},
		})
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "LIST_RENAME_FAILED", "Liste adı güncellenemedi", err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Liste adı güncellendi!", "name": input.Name})
	}
}

// ReorderList — Listedeki filmlerin sırasını günceller
// Body: { "tmdbIds": [38, 19404, 694, ...] } — yeni sıradaki tmdbId dizisi
func ReorderList() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		listObjID, ok := parseObjectIDOrBadRequest(c, c.Param("listId"), "liste kimliği")
		if !ok {
			return
		}

		var input struct {
			TmdbIds []int `json:"tmdbIds" binding:"required"`
		}
		if err := c.ShouldBindJSON(&input); err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "tmdbIds dizisi gerekli", nil)
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		listColl := config.GetCollection(config.DB, "lists")
		var list models.List
		if err := listColl.FindOne(ctx, bson.M{"_id": listObjID, "userId": userID}).Decode(&list); err != nil {
			errorResponse(c, http.StatusForbidden, "LIST_FORBIDDEN", "Bu liste bulunamadı veya size ait değil", nil)
			return
		}

		itemColl := config.GetCollection(config.DB, "list_items")
		for i, tmdbID := range input.TmdbIds {
			if _, err := itemColl.UpdateOne(ctx,
				bson.M{"listId": listObjID, "tmdbId": tmdbID},
				bson.M{"$set": bson.M{"position": i + 1}},
			); err != nil {
				errorResponse(c, http.StatusInternalServerError, "LIST_REORDER_FAILED", "Liste sıralaması güncellenemedi", err.Error())
				return
			}
		}

		c.JSON(http.StatusOK, gin.H{"message": "Sıralama güncellendi"})
	}
}

// PreviewLetterboxdImport — Yalnızca dosyayı okur, listeleri parse eder ve UI için her listenin ilk posterini döner
func PreviewLetterboxdImport() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isLetterboxdImportEnabled() {
			errorResponse(c, http.StatusServiceUnavailable, "IMPORT_DISABLED", "Letterboxd import özelliği şu anda kapalı", nil)
			return
		}

		_, ok := mustUserID(c)
		if !ok {
			return
		}

		fileHeader, err := c.FormFile("file")
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "FILE_REQUIRED", "Yüklenecek dosya bulunamadı", nil)
			return
		}

		f, err := fileHeader.Open()
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "FILE_OPEN_FAILED", "Dosya açılamadı", err.Error())
			return
		}
		defer f.Close()

		payload, err := io.ReadAll(io.LimitReader(f, maxImportUploadBytes+1))
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "FILE_READ_FAILED", "Dosya okunamadı", err.Error())
			return
		}
		if len(payload) > maxImportUploadBytes {
			errorResponse(c, http.StatusRequestEntityTooLarge, "UPLOAD_TOO_LARGE", "Dosya çok büyük (max 10MB)", nil)
			return
		}

		parsedLists, warnings, err := ParseLetterboxdPayloadPublic(payload, fileHeader.Filename)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "PARSE_FAILED", "Dosya ayrıştırılamadı", err.Error())
			return
		}

		creatorStr := ""
		if isZipPayload(payload, fileHeader.Filename) {
			creatorStr = extractUsernameFromZip(payload)
		}

		// UI için sadece her listenin ilk filminin posterini hızlıca fetch et
		type PreviewList struct {
			Name           string `json:"name"`
			TotalItems     int    `json:"totalItems"`
			FirstPosterURL string `json:"firstPosterUrl"`
		}

		var previewResponse []PreviewList

		for i := range parsedLists {
			firstPoster := ""
			// İlk elemanın tam TMDB ID'sini çöz, sadece afiş için
			if len(parsedLists[i].Items) > 0 {
				firstItem := &parsedLists[i].Items[0]
				MatchTMDBMoviePublic(firstItem)
				firstPoster = firstItem.PosterURL
			}

			previewResponse = append(previewResponse, PreviewList{
				Name:           parsedLists[i].Name,
				TotalItems:     len(parsedLists[i].Items),
				FirstPosterURL: firstPoster,
			})
		}

		c.JSON(http.StatusOK, gin.H{
			"message":  "Önizleme başarıyla oluşturuldu",
			"warnings": warnings,
			"lists":    previewResponse,
			"creator":  creatorStr,
		})
	}
}

func extractUsernameFromZip(payload []byte) string {
	zr, err := zip.NewReader(bytes.NewReader(payload), int64(len(payload)))
	if err != nil {
		return ""
	}
	for _, f := range zr.File {
		baseName := filepath.Base(filepath.ToSlash(f.Name))
		if strings.EqualFold(baseName, "profile.csv") || strings.EqualFold(f.Name, "profile.csv") {
			rc, err := f.Open()
			if err != nil {
				return ""
			}
			defer rc.Close()
			reader := csv.NewReader(rc)
			reader.FieldsPerRecord = -1
			reader.LazyQuotes = true
			reader.TrimLeadingSpace = true
			records, err := reader.ReadAll()
			if err != nil || len(records) < 2 {
				return ""
			}
			usernameIdx := -1
			for i, header := range records[0] {
				// BOM karakterini ve boşlukları temizle
				cleanHeader := strings.TrimSpace(strings.Trim(header, "\ufeff\""))
				if strings.EqualFold(cleanHeader, "Username") {
					usernameIdx = i
					break
				}
			}
			if usernameIdx >= 0 && usernameIdx < len(records[1]) {
				val := strings.TrimSpace(records[1][usernameIdx])
				// Tırnak içindeyse temizle
				if strings.HasPrefix(val, "\"") && strings.HasSuffix(val, "\"") && len(val) >= 2 {
					val = val[1 : len(val)-1]
				}
				return val
			}
		}
	}
	return ""
}

// StartLetterboxdImport — ZIP/CSV dosyasını alır, DB'ye ImportJob kaydeder ve RabbitMQ'ya kuyruklar
func StartLetterboxdImport() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isLetterboxdImportEnabled() {
			errorResponse(c, http.StatusServiceUnavailable, "IMPORT_DISABLED", "Letterboxd import ozelligi su anda kapali", nil)
			return
		}

		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		strategy := c.PostForm("strategy")
		if strategy == "" {
			strategy = "merge" // Default strategy
		}

		selectedListNamesRaw := strings.TrimSpace(c.PostForm("selectedListNames"))
		selectedListNames := make([]string, 0)
		if selectedListNamesRaw != "" {
			if strings.HasPrefix(selectedListNamesRaw, "[") {
				if err := json.Unmarshal([]byte(selectedListNamesRaw), &selectedListNames); err != nil {
					errorResponse(c, http.StatusBadRequest, "INVALID_SELECTED_LISTS", "selectedListNames formatı geçersiz", err.Error())
					return
				}
			} else {
				parts := strings.Split(selectedListNamesRaw, ",")
				for _, p := range parts {
					name := strings.TrimSpace(p)
					if name != "" {
						selectedListNames = append(selectedListNames, name)
					}
				}
			}
		}

		fileHeader, err := c.FormFile("file")
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "FILE_REQUIRED", "Yuklenecek dosya bulunamadi", nil)
			return
		}

		f, err := fileHeader.Open()
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "FILE_OPEN_FAILED", "Dosya acilamadi", err.Error())
			return
		}
		defer f.Close()

		payload, err := io.ReadAll(io.LimitReader(f, maxImportUploadBytes+1))
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "FILE_READ_FAILED", "Dosya okunamadi", err.Error())
			return
		}
		if len(payload) > maxImportUploadBytes {
			errorResponse(c, http.StatusRequestEntityTooLarge, "UPLOAD_TOO_LARGE", "Dosya cok buyuk (max 10MB)", nil)
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		// ImportJob kaydı oluştur
		importJob := models.ImportJob{
			UserID:            userID,
			Status:            "pending",
			TotalItems:        0,
			ProcessedItems:    0,
			FailedItems:       0,
			Progress:          0,
			Payload:           payload,
			FileName:          fileHeader.Filename,
			Strategy:          strategy,
			SelectedListNames: selectedListNames,
			CreatedAt:         time.Time{}, // MongoDB sürücüsü zamanı dolduracaktır, custom için time.Now()
			UpdatedAt:         time.Now(),
		}

		importJob.CreatedAt = time.Now()

		importJobsColl := config.GetCollection(config.DB, "import_jobs")
		res, err := importJobsColl.InsertOne(ctx, importJob)
		if err != nil || res.InsertedID == nil {
			errorResponse(c, http.StatusInternalServerError, "DB_ERROR", "Job kaydı açılamadı", err.Error())
			return
		}

		jobIDHex := res.InsertedID.(primitive.ObjectID).Hex()

		// RabbitMQ'ya At
		if config.RabbitMQManagerInstance != nil {
			type CSVImportMessage struct {
				JobID             string   `json:"jobId"`
				UserID            string   `json:"userId"`
				Strategy          string   `json:"strategy"`
				SelectedListNames []string `json:"selectedListNames,omitempty"`
			}
			msgData, _ := json.Marshal(CSVImportMessage{
				JobID:             jobIDHex,
				UserID:            userID,
				Strategy:          strategy,
				SelectedListNames: selectedListNames,
			})
			_ = config.RabbitMQManagerInstance.Publish("", "csv_import_queue", msgData)
		} else {
			// RabbitMQ Yoksa Logla veya Hata ver
			log.Println("⚠️ RabbitMQ çalışmıyor, CSV worker kullanılamaz!")
			errorResponse(c, http.StatusInternalServerError, "QUEUE_ERROR", "Sistem arka plan görevini sıraya alamadı.", nil)
			return
		}

		c.JSON(http.StatusAccepted, gin.H{
			"message": "İçe aktarım sıraya alındı, işlem arka planda yapılıyor.",
			"jobId":   jobIDHex,
		})
	}
}
func ResolveTargetListPublic(
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

func ParseLetterboxdPayloadPublic(payload []byte, filename string) ([]parsedList, []string, error) {
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

func MatchTMDBMoviePublic(item *parsedListItem) {
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

// GetImportProgress — CSV içe aktarım işleminin yüzdelik durumunu döner
func GetImportProgress() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := mustUserID(c)
		if !ok {
			return
		}

		jobIDHex := c.Param("jobId")
		objID, err := primitive.ObjectIDFromHex(jobIDHex)
		if err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_JOB_ID", "Geçersiz job ID", nil)
			return
		}

		ctx, cancel, _ := requestContext(c)
		defer cancel()

		var job models.ImportJob
		importJobsColl := config.GetCollection(config.DB, "import_jobs")

		err = importJobsColl.FindOne(ctx, bson.M{"_id": objID, "userId": userID}).Decode(&job)
		if err != nil {
			errorResponse(c, http.StatusNotFound, "JOB_NOT_FOUND", "İşlem bulunamadı", nil)
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"jobId":          jobIDHex,
			"status":         job.Status,
			"progress":       job.Progress,
			"totalItems":     job.TotalItems,
			"processedItems": job.ProcessedItems,
			"failedItems":    job.FailedItems,
			"logs":           job.Logs,
			"updatedAt":      job.UpdatedAt,
		})
	}
}
