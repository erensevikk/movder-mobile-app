# 🎬 Movder — Anlık Film Eşleşme ve Sinema Odaklı Sosyal Ağ Platformu

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Badge"/>
  <img src="https://img.shields.io/badge/Go%20%2F%20Gin-1.20%2B-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go Badge"/>
  <img src="https://img.shields.io/badge/MongoDB-7.0-47A248?style=for-the-badge&logo=mongodb&logoColor=white" alt="MongoDB Badge"/>
  <img src="https://img.shields.io/badge/Redis-7.2-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis Badge"/>
  <img src="https://img.shields.io/badge/RabbitMQ-3.12-FF6600?style=for-the-badge&logo=rabbitmq&logoColor=white" alt="RabbitMQ Badge"/>
  <img src="https://img.shields.io/badge/Docker%20Compose-Blue?style=for-the-badge&logo=docker&logoColor=white" alt="Docker Badge"/>
</div>

---

## 📌 Proje Genel Bakışı ve Konsepti

**Movder**, sinema ve dizi tutkunlarının izleme deneyimlerini paylaşıp anlık sosyalleşmelerini sağlayan, **"Sinema ve Dizi Dünyasının Makromusic'i"** olarak tasarlanmış gerçek zamanlı bir film eşleşme ve sosyal ağ platformudur.

### 🔍 Çözülen Temel Problem
Mevcut sinema platformları (forumlar, Letterboxd vb.) statik ve asenkron etkileşimler sunar. Kullanıcılar bir içeriği izlerken yaşadıkları heyecanı, teorilerini veya anlık tepkilerini **birebir ve gerçek zamanlı** paylaşabilecekleri dinamik bir ortam bulamamaktadır.

### 💡 Movder Çözümü
Kullanıcı, izlemekte olduğu filmi/diziyi seçip **"Şu an bunu izliyorum"** durumunu başlattığı an:
1. Profilinde canlı bir izleme sayacı başlar.
2. Arka planda **RabbitMQ** ve **Redis** destekli eşleşme motoru, aynı içeriği izleyen başka bir aktif kullanıcıyı tespit eder.
3. Eşleşme sağlandığı anda **WebSocket** üzerinden iki kullanıcı özel bir sohbet odasına yönlendirilir.
4. Sohbet sonrasında iki taraf da onay verirse **kalıcı arkadaşlık** kurulur.

---

## 🚀 Öne Çıkan Özellikler (Core Features)

*   **⚡ Canlı Sayaç ve İzleme Durumu:** Kullanıcının başlattığı durum bilgisi, zaman damgasıyla birlikte **Redis** üzerinde tutulur. Profilde dinamik olarak *"1 saat 15 dakikadır Inception izliyor"* gibi canlı sayaçlar görüntülenir.
*   **🎯 Gerçek Zamanlı Eşleşme (Matchmaking Radar):** Aynı filmi veya diziyi izleyen kullanıcılar, engelleme filtreleri ve şehir bazlı konum kısıtlamaları (LocalOnly) göz önünde bulundurularak saniyeler içinde eşleştirilir.
*   **💬 WebSocket Tabanlı Anlık Sohbet:** Eşleşen kullanıcılar arasında anında JWT doğrulamalı, kesintisiz ve güvenli bir sohbet odası kurulur. Okundu bilgileri (read_receipt) ve yazıyor durumları gerçek zamanlı iletilir.
*   **📊 Letterboxd CSV Aktarımı:** Kullanıcıların Letterboxd'den dışa aktardıkları CSV dosyalarını arka planda asenkron olarak ayrıştıran worker yapısı sayesinde, tüm izleme geçmişi saniyeler içinde Movder kütüphanesine aktarılır.
*   **🎬 TMDB API Entegrasyonu:** Dünyadaki tüm film/dizi verileri, posterleri, özetleri ve tür bilgileri doğrudan TMDB API altyapısı üzerinden çekilir ve aranır.
*   **🏆 Favori Film Vitrini:** Kullanıcıların profillerinde sergileyebileceği, en sevdikleri 4 filmi öne çıkaran dinamik bir vitrin alanı.
*   **📂 Özel Listeler ve Sıralama:** Kullanıcıların kendi oluşturdukları listeleri sürükle-bırak yöntemiyle reorderable olarak düzenleyebildiği liste yönetim alanı.

---

## 🛠️ Teknoloji Yığını ve Sistem Mimarisi

Movder mimarisi, **"Vitrin" (Frontend)** ve **"Mutfak" (Backend)** şeklinde tamamen ayrılmış, yüksek performanslı ve eşzamanlı çalışmaya uygun mikro yapıda tasarlanmıştır.

### A. Vitrin — Mobil Arayüz (Frontend)
| Katman | Teknoloji / Kütüphane | Kullanım Amacı / Açıklama |
| :--- | :--- | :--- |
| **Framework** | **Flutter (Dart)** | Tek kod tabanından yüksek performanslı iOS + Android çıktıları üretmek. |
| **State Management** | **MVVM Mimarisi** | `ChangeNotifier` tabanlı ViewModel'lar, `BaseViewModel` altyapısı ve manuel Dependency Injection (`AppScope`). |
| **Arayüz Tasarımı** | **Cyberpunk / Romantic Dark** | Neon efektli, koyu temalı (`0xFF0F0F0F` zemin), yüksek görsel estetiğe sahip özelleştirilmiş UI elemanları. |
| **Asenkron Görüntüler** | `cached_network_image` | TMDB afişlerinin cihaz belleğinde önbelleğe alınarak hızlı yüklenmesi. |
| **Veri Depolama** | `shared_preferences` | Kullanıcı oturum JWT ve cihaz ayarlarının yerel olarak saklanması. |
| **WebSocket Bağlantısı**| `web_socket_channel` | Gerçek zamanlı mesajlaşma ve eşleşme radarı sinyalizasyonu. |

### B. Mutfak — Sunucu ve Altyapı (Backend)
| Katman | Teknoloji / Kütüphane | Kullanım Amacı / Açıklama |
| :--- | :--- | :--- |
| **Ana Sunucu** | **Go (Golang) + Gin** | Goroutine desteğiyle düşük kaynak tüketiminde binlerce anlık isteği eşzamanlı işleme yeteneği. |
| **Kuyruk Yönetimi** | **RabbitMQ** | Eşleşme bekleyen adayları sıraya sokan ve CSV yükleme görevlerini kuyrukta asenkron dağıtan servis. |
| **Hızlı Bellek** | **Redis** | Aday havuzu, canlı izleme sayaçları, online statüleri ve geçici oda verilerinin ultra hızlı okunması/yazılması. |
| **Veritabanı** | **MongoDB (NoSQL)** | Mesaj geçmişleri, kullanıcı bilgileri, listeler ve bildirimler gibi esnek JSON şemalarının saklanması. |
| **DevOps / Altyapı** | **Docker Compose** | MongoDB, Redis ve RabbitMQ altyapılarını tek komutla izole ve sürüm uyumlu şekilde ayağa kaldırma. |

---

## 🏗️ Sistem İşleyiş Senaryosu (Matchmaking & User Flow)

Sistemin gerçek zamanlı eşleşme ve anlık mesajlaşma döngüsü aşağıdaki teknik şemada özetlenmiştir:

```mermaid
sequenceDiagram
    autonumber
    actor U1 as Kullanıcı 1 (Inception İzliyor)
    actor U2 as Kullanıcı 2 (Inception İzliyor)
    participant API as Go API Sunucusu (Gin)
    participant Redis as Redis Cache (Sorted Sets)
    participant MQ as RabbitMQ Kuyruğu
    participant DB as MongoDB (NoSQL)

    U1->>API: Durum Paylaş: "Inception" (LocalOnly: false)
    API->>Redis: Canlı sayaç durumunu kaydet (TTL: 2 saat)
    API->>Redis: Aday Havuzuna Ekle (match_candidates:tmdbID)
    U2->>API: Durum Paylaş: "Inception" (LocalOnly: false)
    API->>Redis: Canlı sayaç durumunu kaydet (TTL: 2 saat)
    API->>Redis: Aday Havuzuna Ekle (match_candidates:tmdbID)
    
    Note over API, Redis: FindMatch() Tetiklenir: Engelleme & Şehir (LocalOnly) filtreleri kontrol edilir
    
    API->>Redis: İki Adayı Havuzdan Çıkar
    API->>Redis: Eşleşme Kaydet (chatroom:roomID)
    API-->>U1: WebSocket Odası Sinyali (RoomID)
    API-->>U2: WebSocket Odası Sinyali (RoomID)
    
    Note over U1, U2: WebSocket Üzerinden Canlı Sohbet Başlar
    
    U1->>API: "Merhaba!" Mesajı Gönder (WS Frame)
    API->>U2: Mesajı İlet (Broadcast)
    API->>API: MessagePersistencePool'a Görev Submit Et (Asenkron)
    API->>DB: MongoDB'ye Kaydet (Worker Goroutine)
```

---

## 📁 Proje Klasör Yapısı (Folder Structure)

Proje, frontend ve backend kodlarının aynı depoda düzenlendiği monorepo yapısına sahiptir:

```
Movder/                          # Kök dizin
├── lib/                         # FLUTTER (FRONTEND) UYGULAMASI
│   ├── main.dart                # Giriş noktası (Bootstrap başlatıcı)
│   ├── app/                     # Uygulama kabuğu, bağımlılık enjeksiyonu ve Bottom Nav
│   │   ├── bootstrap.dart       # Başlangıç servislerinin init edilmesi
│   │   ├── app.dart             # MaterialApp kök widget'ı (MovderApp)
│   │   ├── app_scope.dart       # Manuel Dependency Injection (Singleton depolar)
│   │   └── app_shell_screen.dart# BottomNavigationBar ile ana ekran yönetimi
│   ├── core/                    # Çekirdek kütüphane ve altyapı
│   │   ├── base/                # BaseViewModel, Result ve AppFailure yapıları
│   │   ├── mixins/              # Arayüz yükleme durumu kontrolü (LoadingStateMixin)
│   │   ├── network/             # ApiClient (HTTP/Bearer JWT istek katmanı)
│   │   ├── services/            # AuthStorageService, MediaPickerService
│   │   └── theme/               # AppColors (Özel renk tokenları), AppTheme
│   ├── features/                # Modüler MVVM ekran klasörleri
│   │   ├── auth/                # Kayıt & Giriş işlemleri
│   │   ├── home/                # Ana sayfa ve film arama radarı
│   │   ├── match/               # Eşleşme arama radarı arayüzü
│   │   ├── chat/                # WebSocket anlık mesajlaşma ve oda listesi
│   │   ├── profile/             # Profil sayfası, Letterboxd CSV yükleme alanı
│   │   ├── movies/              # Film detayları ve benzer öneriler
│   │   ├── lists/               # Sürükle-bırak özellikli listeler
│   │   ├── notifications/       # Sistem ve sosyal bildirimler
│   │   └── settings/            # Ayarlar (Güvenlik, Gizlilik, Şifre Değiştirme)
│   └── shared/                  # Ortak bileşenler ve widget'lar
│
├── backend/                     # GO (BACKEND) API SUNUCUSU
│   ├── main.go                  # Backend giriş kapısı, Gin rotaları ve graceful shutdown
│   ├── config/                  # Bağlantı yöneticileri ve kuyruk havuzları
│   │   ├── db.go                # MongoDB şemaları, eşsiz indeks tanımlamaları
│   │   ├── env.go               # Ortam değişkeni (.env) okuma, Docker tespiti
│   │   ├── rabbitmq_manager.go  # RabbitMQ bağlantısı, otomatik yeniden bağlanma
│   │   ├── redis.go             # Redis Client ilklendirme
│   │   └── worker_pool.go       # Eşzamanlı arka plan işçi havuzları (MessagePersistence)
│   ├── controllers/             # HTTP & WS handler kodları (Chat, Match, User vb.)
│   ├── routes/                  # API rota grupları tanımları
│   ├── services/                # İş mantığı (Matchmaking motoru, TMDB API istekleri)
│   ├── models/                  # Go veri modelleri (Kullanıcı, Mesaj, Job yapıları)
│   ├── middleware/              # JWT doğrulama ve CORS kontrol middleware'leri
│   ├── workers/                 # Arka planda kuyruk tüketen worker'lar (csv_worker)
│   └── docker-compose.yml       # Mongo, Redis ve RabbitMQ docker kurulumları
│
└── .env                         # Ortam değişkenleri dosyası
```

---

## ⚡ Gelişmiş Teknik Detaylar (Architectural Highlights)

### 1. Eşzamanlı Arka Plan İşçi Havuzları (Worker Pools)
WebSocket üzerinden saniyede yüzlerce mesaj gönderildiğinde, her mesajı doğrudan MongoDB'ye senkron yazmak API iş parçacıklarının (threads) kilitlenmesine neden olabilir. Movder, bunun önüne geçmek için **Write-Behind Cache** yaklaşımını kullanır:
*   `MessagePersistencePool`: 10 paralel worker ve 1000 kapasiteli tampon (buffer) ile çalışır.
*   `ReadReceiptPool`: 5 paralel worker ve 500 buffer kapasitesi ile okundu bilgilerini günceller.
*   Tampon dolduğunda otomatik **Backpressure** uygulanarak sunucu belleğinin aşırı şişmesi (Memory Exhaustion) engellenir.

### 2. Redis Sorted Sets ile Aday Havuzu Yönetimi
Eşleşme arayan adayların sırası ve zaman damgaları Redis sorted set yapısı (`match_candidates:<tmdbId>`) üzerinde puanlanarak saklanır.
*   Adaylar zaman damgasına göre sıralandığı için en uzun süredir bekleyen kullanıcı öncelikli olarak eşleştirilir.
*   Eşleşme radarı 2 dakikalık bir TTL'e sahiptir. Bu sayede uygulamayı aniden kapatan (zombi) kullanıcılar havuzdan otomatik olarak temizlenir.

---

## 🛠️ Yerel Geliştirme Ortamı Kurulumu (Development Setup)

Bu bölüm, projeyi yerel geliştirme ortamında çalıştırmak ve test etmek için gerekli asgari adımları içerir.

### 📋 Gereksinimler
*   Docker ve Docker Compose
*   Go SDK (1.20+)
*   Flutter SDK (3.10+)
*   TMDB API Key (Film bilgileri için)

### 1. Ortam Değişkenleri (`.env`)
Proje kök dizininde `.env` isimli bir dosya oluşturup yerel ayarlarınızı tanımlayın:
```env
TMDB_API_KEY=your_tmdb_api_key
TMDB_READ_TOKEN=your_tmdb_read_token
MONGODB_URI=mongodb://admin:password123@localhost:27017
REDIS_URI=redis://:redispass123@localhost:6379
RABBITMQ_URI=amqp://admin:rabbitpass123@localhost:5672/
JWT_SECRET=your_jwt_signing_secret
FEATURE_LETTERBOXD_IMPORT=true
```

### 2. Altyapı Servisleri (Docker)
MongoDB, Redis ve RabbitMQ konteynerlerini başlatın:
```bash
cd backend
docker-compose up -d
```

### 3. API Sunucusu (Go)
Bağımlılıkları yükleyin ve yerel API sunucusunu çalıştırın:
```bash
cd backend
go run main.go
```
*Sunucu `http://localhost:8080` adresinde çalışmaya başlayacaktır.*

### 4. Mobil Uygulama (Flutter)
Paketleri indirip uygulamayı emülatörünüzde başlatın:
```bash
flutter pub get
flutter run
```

---

## 📄 Lisans

Bu proje gizli ve kişisel kullanım için tasarlanmıştır. Tüm hakları saklıdır.
