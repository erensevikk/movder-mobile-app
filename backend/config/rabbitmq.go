package config

import (
	"fmt"
	"log"
	"sync"

	amqp "github.com/rabbitmq/amqp091-go"
)

// RabbitConn ve RabbitChannel artık RabbitMQManagerInstance üzerinden yönetiliyor
// Bu dosya geriye dönük uyumluluk için korunmaktadır
// Lütfen yeni RabbitMQ Manager'ı kullanın

var (
	RabbitConn    *amqp.Connection
	RabbitChannel *amqp.Channel
	rabbitOnce    sync.Once
)

// ConnectRabbitMQ eski bağlantı fonksiyonu - yeni mimariye yönlendirir
// @deprecated Bunun yerine InitRabbitMQManager() kullanın
func ConnectRabbitMQ() {
	// Yeni RabbitMQ Manager'ı başlat (zaten başlatılmışsa tekrarlanmaz)
	if RabbitMQManagerInstance == nil {
		InitRabbitMQManager()
	}

	// Eski değişkenleri güncelle (geriye dönük uyumluluk için)
	if RabbitMQManagerInstance != nil {
		RabbitConn = RabbitMQManagerInstance.conn
		ch, err := RabbitMQManagerInstance.GetPublishChannel()
		if err == nil {
			RabbitChannel = ch
		}
	}

	fmt.Println("✅ RabbitMQ (eski mod) bağlantısı başarıyla kuruldu.")
}

// GetRabbitChannel publish channel döner (geriye dönük uyumluluk)
func GetRabbitChannel() (*amqp.Channel, error) {
	if RabbitMQManagerInstance != nil {
		return RabbitMQManagerInstance.GetPublishChannel()
	}

	// Fallback: eski channel'ı dön
	if RabbitChannel != nil && !RabbitChannel.IsClosed() {
		return RabbitChannel, nil
	}

	// Channel yoksa yeniden bağlan
	ConnectRabbitMQ()
	return RabbitChannel, nil
}

// EnsureQueue eski kuyruk oluşturma fonksiyonu
// @deprecated Bunun yerine RabbitMQManager.DeclareMatchQueue kullanın
func EnsureQueue(queueName string) (amqp.Queue, error) {
	ch, err := GetRabbitChannel()
	if err != nil {
		return amqp.Queue{}, err
	}

	return ch.QueueDeclare(
		queueName,
		false, // durable
		true,  // autoDelete
		false, // exclusive
		false, // noWait
		nil,   // args
	)
}

// CloseRabbitMQ bağlantıları kapatır
func CloseRabbitMQ() {
	if RabbitMQManagerInstance != nil {
		RabbitMQManagerInstance.Stop()
		log.Println("🔌 RabbitMQ bağlantıları kapatıldı")
	}
}

// RabbitMQStatus bağlantı durumunu döner
func RabbitMQStatus() map[string]interface{} {
	if RabbitMQManagerInstance != nil {
		return map[string]interface{}{
			"connected": RabbitMQManagerInstance.IsConnected(),
			"name":      RabbitMQManagerInstance.GetConnectionName(),
		}
	}
	return map[string]interface{}{
		"connected": false,
		"name":      "not initialized",
	}
}
