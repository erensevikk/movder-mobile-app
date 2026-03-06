package controllers

import (
	"movder-backend/config"
	"movder-backend/models"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

func defaultPrivacySettings() models.PrivacySettings {
	return models.PrivacySettings{
		WatchingVisibility: "friends_and_matches",
		ProfileVisibility:  "public",
		SearchDiscoverable: true,
	}
}

func normalizePrivacySettings(settings *models.PrivacySettings) models.PrivacySettings {
	normalized := defaultPrivacySettings()
	if settings == nil {
		return normalized
	}

	switch strings.TrimSpace(settings.WatchingVisibility) {
	case "public", "friends_and_matches", "hidden":
		normalized.WatchingVisibility = settings.WatchingVisibility
	}

	switch strings.TrimSpace(settings.ProfileVisibility) {
	case "public", "friends_only":
		normalized.ProfileVisibility = settings.ProfileVisibility
	}

	normalized.SearchDiscoverable = settings.SearchDiscoverable

	return normalized
}

func userPrivacySettings(user models.User) models.PrivacySettings {
	return normalizePrivacySettings(user.PrivacySettings)
}

func canViewerSeeProfileDetails(viewerID, targetID primitive.ObjectID, isFriend bool, privacy models.PrivacySettings) bool {
	if viewerID == targetID {
		return true
	}
	if privacy.ProfileVisibility == "public" {
		return true
	}
	return isFriend
}

func canViewerSeeWatching(viewerIDHex string, viewerID, targetID primitive.ObjectID, isFriend, isMatched bool, privacy models.PrivacySettings) bool {
	if viewerID == targetID {
		return true
	}

	switch privacy.WatchingVisibility {
	case "public":
		return true
	case "hidden":
		return false
	default:
		return isFriend || isMatched || viewerIDHex == targetID.Hex()
	}
}

func GetPrivacySettings() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDHex, ok := mustUserID(c)
		if !ok {
			return
		}
		objectID, ok := parseObjectIDOrBadRequest(c, userIDHex, "kullanıcı kimliği")
		if !ok {
			return
		}

		var user models.User
		userCollection := config.GetCollection(config.DB, "users")
		if err := userCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&user); err != nil {
			errorResponse(c, http.StatusNotFound, "USER_NOT_FOUND", "Kullanıcı bulunamadı", err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"privacySettings": userPrivacySettings(user),
		})
	}
}

func UpdatePrivacySettings() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel, _ := requestContext(c)
		defer cancel()

		userIDHex, ok := mustUserID(c)
		if !ok {
			return
		}
		objectID, ok := parseObjectIDOrBadRequest(c, userIDHex, "kullanıcı kimliği")
		if !ok {
			return
		}

		var existing models.User
		userCollection := config.GetCollection(config.DB, "users")
		if err := userCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&existing); err != nil {
			errorResponse(c, http.StatusNotFound, "USER_NOT_FOUND", "Kullanıcı bulunamadı", err.Error())
			return
		}

		current := userPrivacySettings(existing)
		next := current

		var input map[string]interface{}
		if err := c.ShouldBindJSON(&input); err != nil {
			errorResponse(c, http.StatusBadRequest, "INVALID_BODY", "Geçersiz veri", err.Error())
			return
		}

		if raw, ok := input["watchingVisibility"]; ok {
			if value, ok := raw.(string); ok {
				next.WatchingVisibility = value
			}
		}
		if raw, ok := input["profileVisibility"]; ok {
			if value, ok := raw.(string); ok {
				next.ProfileVisibility = value
			}
		}
		if raw, ok := input["searchDiscoverable"]; ok {
			if value, ok := raw.(bool); ok {
				next.SearchDiscoverable = value
			}
		}

		next = normalizePrivacySettings(&next)

		_, err := userCollection.UpdateOne(
			ctx,
			bson.M{"_id": objectID},
			bson.M{"$set": bson.M{"privacy_settings": next}},
		)
		if err != nil {
			errorResponse(c, http.StatusInternalServerError, "PRIVACY_UPDATE_FAILED", "Gizlilik ayarları güncellenemedi", err.Error())
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":         "Gizlilik ayarları güncellendi",
			"privacySettings": next,
		})
	}
}
