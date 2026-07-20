package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// ImportJob Letterboxd CSV iÃ§e aktarÄ±m iÅŸlemini takip etmek iÃ§in model
type ImportJob struct {
	ID                primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	UserID            string             `bson:"userId" json:"userId"`
	Status            string             `bson:"status" json:"status"` // pending, processing, completed, failed
	TotalItems        int                `bson:"totalItems" json:"totalItems"`
	ProcessedItems    int                `bson:"processedItems" json:"processedItems"`
	FailedItems       int                `bson:"failedItems" json:"failedItems"`
	Progress          int                `bson:"progress" json:"progress"` // % (0-100)
	Payload           []byte             `bson:"payload,omitempty" json:"-"`
	FileName          string             `bson:"fileName,omitempty" json:"fileName"`
	Strategy          string             `bson:"strategy,omitempty" json:"strategy"`
	SelectedListNames []string           `bson:"selectedListNames,omitempty" json:"selectedListNames,omitempty"`
	Logs              []string           `bson:"logs,omitempty" json:"logs,omitempty"`
	CreatedAt         time.Time          `bson:"createdAt" json:"createdAt"`
	UpdatedAt         time.Time          `bson:"updatedAt" json:"updatedAt"`
}
