package config

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

// RabbitMQConfig RabbitMQ bağlantı yapılandırması
type RabbitMQConfig struct {
	URI             string
	ConnectionName  string
	MaxRetries      int
	RetryDelay      time.Duration
	PrefetchCount   int
	PublishTimeout  time.Duration
	ConsumerTimeout time.Duration
}

// defaultConfig varsayılan yapılandırma
var defaultConfig = RabbitMQConfig{
	URI:             "", // Runtime'da belirlenir
	ConnectionName:  "movder-connection",
	MaxRetries:      10,
	RetryDelay:      2 * time.Second,
	PrefetchCount:   10,
	PublishTimeout:  5 * time.Second,
	ConsumerTimeout: 30 * time.Second,
}

// getDefaultRabbitMQURI Docker veya local ortama göre URI döner
func getDefaultRabbitMQURI() string {
	rabbitHost := GetRabbitMQHost()
	rabbitUser := GetEnv("RABBITMQ_USER", "admin")
	rabbitPassword := GetEnv("RABBITMQ_PASSWORD", "rabbitpass123")
	rabbitPort := GetEnv("RABBITMQ_PORT", "5672")
	return fmt.Sprintf("amqp://%s:%s@%s:%s/", rabbitUser, rabbitPassword, rabbitHost, rabbitPort)
}

// RabbitMQManager RabbitMQ bağlantı ve kanal yönetimi
type RabbitMQManager struct {
	config          RabbitMQConfig
	conn            *amqp.Connection
	publishChannel  *amqp.Channel
	consumeChannels map[string]*amqp.Channel
	mu              sync.RWMutex
	isConnected     bool
	closeChan       chan *amqp.Error
	notifyCloseChan chan *amqp.Error
	wg              sync.WaitGroup
	ctx             context.Context
	cancel          context.CancelFunc
}

// RabbitMQManagerInstance global RabbitMQ Manager instance
var RabbitMQManagerInstance *RabbitMQManager

// NewRabbitMQManager yeni bir RabbitMQ Manager oluşturur
func NewRabbitMQManager(config ...RabbitMQConfig) *RabbitMQManager {
	cfg := defaultConfig
	if len(config) > 0 {
		cfg = config[0]
	}

	ctx, cancel := context.WithCancel(context.Background())
	return &RabbitMQManager{
		config:          cfg,
		consumeChannels: make(map[string]*amqp.Channel),
		closeChan:       make(chan *amqp.Error, 1),
		notifyCloseChan: make(chan *amqp.Error, 1),
		ctx:             ctx,
		cancel:          cancel,
	}
}

// Connect RabbitMQ'ya bağlanır
func (m *RabbitMQManager) Connect() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Mevcut bağlantıyı kontrol et
	if m.conn != nil && !m.conn.IsClosed() {
		log.Println("✅ RabbitMQ zaten bağlı")
		return nil
	}

	var conn *amqp.Connection
	var err error

	// Bağlantı yeniden deneme döngüsü
	for attempt := 1; attempt <= m.config.MaxRetries; attempt++ {
		conn, err = amqp.Dial(m.config.URI)
		if err == nil {
			break
		}

		log.Printf("⚠️ RabbitMQ bağlantı denemesi %d/%d başarısız: %v",
			attempt, m.config.MaxRetries, err)

		if attempt < m.config.MaxRetries {
			select {
			case <-m.ctx.Done():
				return fmt.Errorf("bağlantı iptal edildi")
			case <-time.After(m.config.RetryDelay):
			}
		}
	}

	if err != nil {
		return fmt.Errorf("RabbitMQ'ya bağlanılamadı: %w", err)
	}

	m.conn = conn
	m.isConnected = true

	// Bağlantı kapanma olaylarını dinle
	m.conn.NotifyClose(m.notifyCloseChan)
	m.conn.NotifyClose(make(chan *amqp.Error, 1))

	log.Printf("✅ RabbitMQ bağlantısı kuruldu (attempt %d)", m.config.MaxRetries)

	// Publish channel oluştur
	if err := m.setupPublishChannel(); err != nil {
		return err
	}

	// DLX ve retry queue'ları oluştur
	if err := m.setupDeadLetterExchange(); err != nil {
		log.Printf("⚠️ DLX kurulumu başarısız: %v", err)
		// DLX kurulumu başarısız olsa da devam edebilir
	}

	return nil
}

// setupPublishChannel publish için ayrı bir channel oluşturur
func (m *RabbitMQManager) setupPublishChannel() error {
	ch, err := m.conn.Channel()
	if err != nil {
		return fmt.Errorf("publish channel oluşturulamadı: %w", err)
	}

	// Publisher confirms etkinleştir
	if err := ch.Confirm(false); err != nil {
		log.Printf("⚠️ Publisher confirm etkinleştirilemedi: %v", err)
	}

	// QoS ayarla (prefetch)
	if err := ch.Qos(m.config.PrefetchCount, 0, false); err != nil {
		log.Printf("⚠️ QoS ayarlanamadı: %v", err)
	}

	m.publishChannel = ch
	log.Println("✅ Publish channel oluşturuldu")

	return nil
}

// setupDeadLetterExchange DLX ve retry queue'ları kurar
func (m *RabbitMQManager) setupDeadLetterExchange() error {
	ch, err := m.conn.Channel()
	if err != nil {
		return fmt.Errorf("DLX channel oluşturulamadı: %w", err)
	}
	defer ch.Close()

	// Dead Letter Exchange oluştur
	err = ch.ExchangeDeclare(
		"movder.dlx", // exchange adı
		"direct",     // exchange tipi
		true,         // durable
		false,        // autoDelete
		false,        // internal
		false,        // noWait
		nil,          // arguments
	)
	if err != nil {
		return fmt.Errorf("DLX oluşturulamadı: %w", err)
	}

	// Dead letter queue oluştur
	_, err = ch.QueueDeclare(
		"movder.dlq", // queue adı
		true,         // durable
		false,        // autoDelete
		false,        // exclusive
		false,        // noWait
		amqp.Table{ // arguments
			"x-dead-letter-exchange": "movder.dlx",
		},
	)
	if err != nil {
		return fmt.Errorf("DLQ oluşturulamadı: %w", err)
	}

	// DLQ'yu DLX'e bağla
	err = ch.QueueBind(
		"movder.dlq",
		"movder.dead",
		"movder.dlx",
		false,
		nil,
	)
	if err != nil {
		return fmt.Errorf("DLQ bind başarısız: %w", err)
	}

	log.Println("✅ DLX ve DLQ kuruldu")
	return nil
}

// GetPublishChannel publish için channel döner
func (m *RabbitMQManager) GetPublishChannel() (*amqp.Channel, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.publishChannel == nil || m.publishChannel.IsClosed() {
		// Channel yeniden oluşturulmalı
		if err := m.reconnectPublishChannel(); err != nil {
			return nil, err
		}
	}

	return m.publishChannel, nil
}

// reconnectPublishChannel publish channel yeniden bağlanır
func (m *RabbitMQManager) reconnectPublishChannel() error {
	if m.conn == nil || m.conn.IsClosed() {
		if err := m.Connect(); err != nil {
			return err
		}
		return m.setupPublishChannel()
	}

	ch, err := m.conn.Channel()
	if err != nil {
		return fmt.Errorf("channel yeniden oluşturulamadı: %w", err)
	}

	if err := ch.Confirm(false); err != nil {
		log.Printf("⚠️ Publisher confirm etkinleştirilemedi: %v", err)
	}

	if err := ch.Qos(m.config.PrefetchCount, 0, false); err != nil {
		log.Printf("⚠️ QoS ayarlanamadı: %v", err)
	}

	m.publishChannel = ch
	log.Println("✅ Publish channel yeniden oluşturuldu")

	return nil
}

// GetConsumeChannel consume için ayrı bir channel döner
func (m *RabbitMQManager) GetConsumeChannel(consumerID string) (*amqp.Channel, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Mevcut channel'ı kontrol et
	if ch, ok := m.consumeChannels[consumerID]; ok && !ch.IsClosed() {
		return ch, nil
	}

	// Yeni channel oluştur
	ch, err := m.conn.Channel()
	if err != nil {
		return nil, fmt.Errorf("consume channel oluşturulamadı: %w", err)
	}

	// QoS ayarla (prefetch - sadece bir mesaj alınsın)
	if err := ch.Qos(1, 0, false); err != nil {
		log.Printf("⚠️ QoS ayarlanamadı: %v", err)
	}

	m.consumeChannels[consumerID] = ch
	log.Printf("✅ Consume channel oluşturuldu: %s", consumerID)

	return ch, nil
}

// CloseConsumeChannel consume channel'ı kapatır
func (m *RabbitMQManager) CloseConsumeChannel(consumerID string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if ch, ok := m.consumeChannels[consumerID]; ok {
		ch.Close()
		delete(m.consumeChannels, consumerID)
		log.Printf("🔌 Consume channel kapatıldı: %s", consumerID)
	}
}

// Publish mesaj publish eder
func (m *RabbitMQManager) Publish(exchange, routingKey string, body []byte, options ...PublishOption) error {
	ch, err := m.GetPublishChannel()
	if err != nil {
		return err
	}

	opts := &PublishOptions{}
	for _, opt := range options {
		opt(opts)
	}

	ctx, cancel := context.WithTimeout(m.ctx, m.config.PublishTimeout)
	defer cancel()

	// Headers'a DLX bilgisi ekle
	headers := amqp.Table{}
	if opts.Headers != nil {
		for k, v := range opts.Headers {
			headers[k] = v
		}
	}
	headers["x-retry-count"] = 0

	err = ch.PublishWithContext(ctx,
		exchange,
		routingKey,
		false, // mandatory
		false, // immediate
		amqp.Publishing{
			ContentType:  "application/json",
			Body:         body,
			DeliveryMode: amqp.Persistent,
			Headers:      headers,
			MessageId:    opts.MessageID,
			Timestamp:    time.Now(),
		},
	)

	if err != nil {
		return fmt.Errorf("mesaj publish edilemedi: %w", err)
	}

	// Publisher confirm bekle
	confirm := ch.NotifyPublish(make(chan amqp.Confirmation, 1))
	select {
	case c := <-confirm:
		if !c.Ack {
			return fmt.Errorf("mesaj nakledilmedi (NACK)")
		}
	case <-time.After(m.config.PublishTimeout):
		return fmt.Errorf("confirm timeout")
	case <-ctx.Done():
		return ctx.Err()
	}

	return nil
}

// PublishWithConfirm publisher confirm ile publish eder
func (m *RabbitMQManager) PublishWithConfirm(exchange, routingKey string, body []byte) error {
	ch, err := m.GetPublishChannel()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(m.ctx, m.config.PublishTimeout)
	defer cancel()

	err = ch.PublishWithContext(ctx,
		exchange,
		routingKey,
		false,
		false,
		amqp.Publishing{
			ContentType:   "application/json",
			Body:          body,
			DeliveryMode:  amqp.Persistent,
			CorrelationId: fmt.Sprintf("%d", time.Now().UnixNano()),
		},
	)

	if err != nil {
		return fmt.Errorf("mesaj publish edilemedi: %w", err)
	}

	// Confirm bekle
	confirm := ch.NotifyPublish(make(chan amqp.Confirmation, 1))
	select {
	case c := <-confirm:
		if !c.Ack {
			return fmt.Errorf("mesaj NACK edildi")
		}
	case <-time.After(m.config.PublishTimeout):
		return fmt.Errorf("confirm timeout")
	}

	return nil
}

// DeclareQueue kuyruk declare eder
func (m *RabbitMQManager) DeclareQueue(name string, durable, autoDelete bool, args amqp.Table) (amqp.Queue, error) {
	ch, err := m.GetPublishChannel()
	if err != nil {
		return amqp.Queue{}, err
	}

	q, err := ch.QueueDeclare(
		name,
		durable,
		autoDelete,
		false,
		false,
		args,
	)
	if err != nil {
		return amqp.Queue{}, fmt.Errorf("kuyruk declare edilemedi: %w", err)
	}

	return q, nil
}

// DeclareQueueWithDLX DLX ile kuyruk declare eder
func (m *RabbitMQManager) DeclareQueueWithDLX(name, exchangeName, routingKey string) (amqp.Queue, error) {
	ch, err := m.GetPublishChannel()
	if err != nil {
		return amqp.Queue{}, err
	}

	args := amqp.Table{
		"x-dead-letter-exchange":    "movder.dlx",
		"x-dead-letter-routing-key": "movder.dead",
	}

	q, err := ch.QueueDeclare(
		name,
		false, // durable - geçici eşleşme verisi
		true,  // autoDelete
		false,
		false,
		args,
	)
	if err != nil {
		return amqp.Queue{}, fmt.Errorf("kuyruk declare edilemedi: %w", err)
	}

	// Kuyruğu exchange'e bağla
	err = ch.QueueBind(
		name,
		routingKey,
		exchangeName,
		false,
		nil,
	)
	if err != nil {
		return amqp.Queue{}, fmt.Errorf("kuyruk bind edilemedi: %w", err)
	}

	return q, nil
}

// Consume tüketici başlatır
func (m *RabbitMQManager) Consume(queue, consumerID string, handler func(amqp.Delivery) bool) error {
	ch, err := m.GetConsumeChannel(consumerID)
	if err != nil {
		return err
	}

	msgs, err := ch.Consume(
		queue,
		consumerID,
		false, // autoAck - manuel ack
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return fmt.Errorf("tüketici başlatılamadı: %w", err)
	}

	m.wg.Add(1)
	go func() {
		defer m.wg.Done()

		for {
			select {
			case <-m.ctx.Done():
				log.Printf("🛑 Tüketici durduruldu: %s", consumerID)
				return
			case msg, ok := <-msgs:
				if !ok {
					log.Printf("⚠️ Kanal kapandı: %s", consumerID)
					return
				}

				// Mesajı işle
				success := handler(msg)
				if success {
					msg.Ack(false)
				} else {
					// Retry kontrolü
					retryCount := int64(0)
					if msg.Headers != nil {
						if rc, ok := msg.Headers["x-retry-count"].(int64); ok {
							retryCount = rc
						}
					}

					if retryCount < 3 {
						// Retry - mesajı başka bir kuyruğa gönder veya geciktir
						msg.Nack(false, false) // DLQ'ya gitsin
					} else {
						// Max retry aşıldı - DLQ'ya gönder
						msg.Nack(false, false)
					}
				}
			}
		}
	}()

	log.Printf("✅ Tüketici başlatıldı: %s -> %s", consumerID, queue)
	return nil
}

// Stop tüm tüketici ve bağlantıları durdurur
func (m *RabbitMQManager) Stop() {
	log.Println("🛑 RabbitMQ Manager durduruluyor...")

	m.cancel()
	m.wg.Wait()

	m.mu.Lock()
	defer m.mu.Unlock()

	// Tüketici channel'ları kapat
	for id, ch := range m.consumeChannels {
		ch.Close()
		delete(m.consumeChannels, id)
	}

	// Publish channel kapat
	if m.publishChannel != nil {
		m.publishChannel.Close()
		m.publishChannel = nil
	}

	// Bağlantıyı kapat
	if m.conn != nil {
		m.conn.Close()
		m.conn = nil
	}

	m.isConnected = false
	log.Println("🔌 RabbitMQ bağlantıları kapatıldı")
}

// IsConnected bağlantı durumunu döner
func (m *RabbitMQManager) IsConnected() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.isConnected && m.conn != nil && !m.conn.IsClosed()
}

// GetConnectionName bağlantı adını döner
func (m *RabbitMQManager) GetConnectionName() string {
	return m.config.ConnectionName
}

// InitRabbitMQManager RabbitMQ Manager'ı başlatır
func InitRabbitMQManager() {
	// Docker veya local için uygun URI oluştr
	defaultURI := getDefaultRabbitMQURI()
	uri := GetEnv("RABBITMQ_URI", defaultURI)

	log.Printf("[DEBUG] RabbitMQ bağlanıyor: host=%s", GetRabbitMQHost())

	RabbitMQManagerInstance = NewRabbitMQManager(RabbitMQConfig{
		URI:             uri,
		ConnectionName:  "movder-main",
		MaxRetries:      10,
		RetryDelay:      2 * time.Second,
		PrefetchCount:   10,
		PublishTimeout:  5 * time.Second,
		ConsumerTimeout: 30 * time.Second,
	})

	if err := RabbitMQManagerInstance.Connect(); err != nil {
		log.Printf("❌ RabbitMQ Manager başlatılamadı: %v", err)
		// Bağlantı başarısız olsa da uygulama çalışmaya devam edebilir
		// Yeniden deneme mekanizması arka planda çalışır
	}

	// Eski global değişkenleri de ayarla (geriye dönük uyumluluk)
	RabbitConn = RabbitMQManagerInstance.conn
	RabbitChannel, _ = RabbitMQManagerInstance.GetPublishChannel()
}

// PublishOptions publish seçenekleri
type PublishOptions struct {
	MessageID string
	Headers   map[string]interface{}
}

// PublishOption publish seçeneği
type PublishOption func(*PublishOptions)

// WithMessageID mesaj ID'si ekler
func WithMessageID(id string) PublishOption {
	return func(o *PublishOptions) {
		o.MessageID = id
	}
}

// WithHeaders headers ekler
func WithHeaders(headers map[string]interface{}) PublishOption {
	return func(o *PublishOptions) {
		o.Headers = headers
	}
}

// Eski fonksiyonlar - geriye dönük uyumluluk için
// Bu fonksiyonlar RabbitMQManagerInstance kullanır

// DeclareMatchQueue eşleşme kuyruğu declare eder
func (m *RabbitMQManager) DeclareMatchQueue(tmdbID int) (amqp.Queue, error) {
	queueName := fmt.Sprintf("match_queue_%d", tmdbID)

	args := amqp.Table{
		"x-dead-letter-exchange":    "movder.dlx",
		"x-dead-letter-routing-key": "movder.dead",
	}

	return m.DeclareQueue(queueName, false, true, args)
}

// EnsureMatchQueue eşleşme kuyruğunun var olduğundan emin olur
func EnsureMatchQueue(tmdbID int) error {
	if RabbitMQManagerInstance == nil {
		return fmt.Errorf("RabbitMQ Manager başlatılmadı")
	}

	_, err := RabbitMQManagerInstance.DeclareMatchQueue(tmdbID)
	return err
}
