package config

import (
	"fmt"
	"log"

	amqp "github.com/rabbitmq/amqp091-go"
)

var RabbitConn *amqp.Connection
var RabbitChannel *amqp.Channel

func ConnectRabbitMQ() {
	rabbitURI := GetEnv("RABBITMQ_URI", "amqp://admin:rabbitpass123@localhost:5672/")

	conn, err := amqp.Dial(rabbitURI)
	if err != nil {
		log.Fatal("RabbitMQ'ya bağlanılamadı: ", err)
	}

	ch, err := conn.Channel()
	if err != nil {
		log.Fatal("RabbitMQ kanalı açılamadı: ", err)
	}

	RabbitConn = conn
	RabbitChannel = ch

	fmt.Println("✅ RabbitMQ bağlantısı başarıyla kuruldu.")
}
