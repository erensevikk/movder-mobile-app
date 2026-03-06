package controllers

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// APIErrorResponse uygulamadaki tüm hata cevapları için ortak şema.
type APIErrorResponse struct {
	Ok      bool        `json:"ok"`
	Code    string      `json:"code"`
	Message string      `json:"message"`
	TraceID string      `json:"traceId,omitempty"`
	Detail  interface{} `json:"detail,omitempty"`
}

const defaultRequestTimeout = 10 * time.Second

// requestContext her HTTP isteği için timeout'lu context ve traceId üretir.
// - Timeout varsayılan olarak 10 saniye
// - traceId varsa header'dan (X-Request-ID), yoksa random olarak üretilir
func requestContext(c *gin.Context) (context.Context, context.CancelFunc, string) {
	traceID := c.GetString("traceId")
	if traceID == "" {
		traceID = c.Request.Header.Get("X-Request-ID")
	}
	if traceID == "" {
		traceID = fmt.Sprintf("%d", time.Now().UnixNano())
	}
	c.Set("traceId", traceID)

	timeout := defaultRequestTimeout
	if v, ok := c.Get("requestTimeout"); ok {
		if d, ok2 := v.(time.Duration); ok2 && d > 0 {
			timeout = d
		}
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), timeout)
	return ctx, cancel, traceID
}

// errorResponse tüm hata cevaplarını tek bir yerden, standart formatta üretir.
func errorResponse(c *gin.Context, status int, code, message string, detail interface{}) {
	traceID := c.GetString("traceId")
	if traceID == "" {
		traceID = c.Request.Header.Get("X-Request-ID")
	}

	resp := APIErrorResponse{
		Ok:      false,
		Code:    code,
		Message: message,
		TraceID: traceID,
	}
	if detail != nil {
		resp.Detail = detail
	}

	c.JSON(status, resp)
}

// mustUserID JWT'den gelen userId'yi zorunlu kılar; yoksa standart 401 döner.
func mustUserID(c *gin.Context) (string, bool) {
	userID := c.GetString("userId")
	if userID == "" {
		errorResponse(c, http.StatusUnauthorized, "UNAUTHORIZED", "Geçerli bir oturum bulunamadı", nil)
		return "", false
	}
	return userID, true
}

// parseObjectIDOrBadRequest gelen hex id'yi ObjectID'ye çevirir; hata olursa 400 döner.
func parseObjectIDOrBadRequest(c *gin.Context, idHex, field string) (primitive.ObjectID, bool) {
	objID, err := primitive.ObjectIDFromHex(idHex)
	if err != nil {
		msg := fmt.Sprintf("Geçersiz %s", field)
		errorResponse(c, http.StatusBadRequest, "INVALID_ID", msg, nil)
		return primitive.NilObjectID, false
	}
	return objID, true
}
