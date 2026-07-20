# Movder — Anlık Film Eşleşme ve Sosyal Ağ Platformu

Bu dosya, projeye dahil olan herhangi bir ajanın (Claude, Gemini vb.)
projenin **amacını, mimarisini, teknoloji yığınını ve işleyişini** tek seferde
kavraması için hazırlanmış resmi proje rehberidir.

---

## 🤖 Ajan Davranış Kuralları

<do_not_act_before_instructions>
Do not jump into implementation or changes files unless clearly 
instructed to make changes. When the user's intent is ambiguous, 
default to providing information, doing research, and providing 
recommendations rather than taking action. Only proceed with edits, 
modifications, or implementations when the user explicitly requests 
them.
</do_not_act_before_instructions>

<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies
between the tool calls, make all of the independent tool calls in
parallel. Prioritize calling tools simultaneously whenever the
actions can be done in parallel rather than sequentially. For
example, when reading 3 files, run 3 tool calls in parallel to read
all 3 files into context at the same time. Maximize use of parallel
tool calls where possible to increase speed and efficiency.
However, if some tool calls depend on previous calls to inform
dependent values like the parameters, do NOT call these tools in
parallel and instead call them sequentially. Never use placeholders
or guess missing parameters in tool calls.
</use_parallel_tool_calls>

<investigate_before_answering>
Never speculate about code you have not opened. If the user
references a specific file, you MUST read the file before
answering. Make sure to investigate and read relevant files BEFORE
answering questions about the codebase. Never make any claims about
code before investigating unless you are certain of the correct
answer - give grounded and hallucination-free answers.
</investigate_before_answering>

**Dil**: Türkçe (UI metinleri, commit mesajları, plan içerikleri Türkçe yazılır.)

---

## 📌 Projenin Amacı ve Konsepti

**Movder**, "Makromusic'in Sinema ve Dizi Versiyonu" olarak tanımlanabilecek
bir **anlık film eşleşme ve sosyal ağ** platformudur.

### Temel Problem

İnsanların bir film veya dizi izlerken yaşadığı **sosyalleşme, teori üretme
ve anlık tepki paylaşma** ihtiyacı, mevcut uygulamalar (lobiler, forumlar)
tarafından **anlık ve birebir** olarak çözülemiyor.

### Çözüm

Kullanıcı, o an izlediği içeriği uygulamada **"Şu an bunu izliyorum"**
şeklinde durum (status) olarak belirler. Sistem saniyeler içinde
**aynı içeriği izleyen** (veya benzer zevklere sahip) başka bir kullanıcıyla
onu **anlık olarak eşleştirir** ve birebir sohbet odasına alır.

---

## ⭐ Temel Özellikler (Core Features)

### 1. Anlık Durum (Status) Bildirimi ve Sayaç

- Kullanıcı "Titanik izliyorum" dediğinde sistem **zaman damgası** (timestamp) alır.
- Profilinde **"1 saat 15 dakikadır Titanik izliyor"** gibi canlı sayaç görünür.
- Sayaç verisi hız için **Redis** üzerinde tutulur.

### 2. Gerçek Zamanlı Eşleşme (Real-time Matchmaking)

- Aynı filmi/diziyi izleyen kullanıcılar **RabbitMQ kuyruğunda** buluşturulur.
- Eşleşme sağlanınca anında **birebir sohbet odası** açılır.

### 3. Karşılıklı Onay ve Arkadaşlık (Opt-in Friends)

- Sohbet sırasında veya sonunda her iki taraf da **"Eşleşmeyi Onayla / Arkadaş Ekle"**
  butonuna basarsa kalıcı olarak takipleşirler.
- Tek taraflı onay arkadaşlık oluşturmaz.

### 4. Profil ve Kütüphane (TMDB Entegrasyonu)

- **TMDB API** altyapısı ile dünyadaki tüm filmler aranıp profile eklenebilir.
- Film afişleri, özetler ve meta veriler TMDB'den çekilir.
- Kullanıcı profilinde "Favori 4 Film" öne çıkarılır.

### 5. Letterboxd CSV Aktarımı

- Kullanıcılar Letterboxd'den dışa aktardıkları **CSV dosyasını** yükleyerek
  tüm izleme geçmişini (binlerce film) Movder'a tek seferde aktarabilir.
- CSV parse işlemi backend tarafında gerçekleştirilir ve MongoDB'ye yazılır.

### 6. 🔮 Yapay Zeka Destekli Zevk Eşleşmesi *(Askıda — Şimdilik geliştirilmiyor)*

- Kuyrukta aynı filmi izleyen kimse yoksa sistem, kullanıcının izleme
  geçmişini **Gemini AI**'a sunarak benzer zevklere sahip aktif bir
  kullanıcıyla **akıllı eşleşme** teklif eder.
- **Bu özellik şu an için geliştirme kapsamı dışındadır.**

---

## 🛠️ Teknoloji Yığını ve Mikroservis Mimarisi

Uygulama **"Vitrin"** (Frontend) ve **"Mutfak"** (Backend) olarak ikiye ayrılır.
Toplam altyapı maliyeti hedefi: **0 TL** (ücretsiz katmanlar).

### A. Vitrin — Mobil Arayüz (Frontend)

| Katman       | Teknoloji       | Açıklama                                                                 |
|--------------|-----------------|--------------------------------------------------------------------------|
| Framework    | **Flutter (Dart)** | Tek kod tabanıyla iOS + Android çıktısı. Animasyonlar, canlı sayaçlar, eşleşme radarı ve WebSocket chat arayüzü burada çalışır. |

### B. Mutfak — Backend ve Altyapı

| Katman               | Teknoloji        | Neden?                                                                                           |
|----------------------|------------------|--------------------------------------------------------------------------------------------------|
| Ana Sunucu (API)     | **Go (Golang) + Gin** | Gin framework üzerine kurulu, goroutine tabanlı mükemmel eşzamanlılık. Binlerce eşzamanlı eşleşme isteğini düşük bellek tüketimiyle karşılar. |
| Mesaj / Görev Kuyruğu | **RabbitMQ**     | Eşleşme arayanları sıraya sokan, doğru kişileri bağlayan ve chat mesajlarını kayıpsız ileten trafik polisi. |
| Hızlı Bellek (Cache) | **Redis**        | Canlı sayaçlar, "Online" durumları ve kısa ömürlü oturum verilerini veritabanını yormadan RAM üzerinde tutar. |
| Kalıcı Veritabanı    | **MongoDB (NoSQL)** | TMDB'den gelen karmaşık JSON film verileri, esnek chat geçmişleri ve devasa izleme listelerini rahat saklama. |

### C. Dış Servisler (API'ler)

| Servis         | Kullanım Amacı                                    | Maliyet  |
|----------------|---------------------------------------------------|----------|
| **TMDB API**   | Film afişleri, özetleri, ID'leri ve meta verileri | Ücretsiz |
| **Gemini API** | Zevk analizi ile akıllı eşleşme *(askıda)*        | Ücretsiz (Google AI Studio Free Tier) |

### D. DevOps ve Canlıya Alma

| Araç                    | Rolü                                                                 |
|-------------------------|----------------------------------------------------------------------|
| **Docker Compose** (`backend/docker-compose.yml`) | Backend altyapısını (MongoDB, Redis, RabbitMQ) tek komutla ayağa kaldırır. Go sunucusu şu an Docker dışında, doğrudan çalıştırılır. |
| **Oracle Cloud (Always Free)** | Docker konteynerlerini 7/24 internete açık tutan, ömür boyu ücretsiz bulut sunucusu. |

---

## 🔄 Sistemin İşleyiş Senaryosu (User Flow)

```
1. Kullanıcı Flutter uygulamasını açar → E-posta ve şifre ile kayıt olur / giriş yapar (JWT tabanlı auth).

2. (Opsiyonel) Letterboxd CSV yükler → Backend parse eder → MongoDB'ye yazar
   → Profil anında dolu ve şık görünür.

3. Kullanıcı "Interstellar izliyorum" butonuna basar.
   └─► Flutter → Go API sunucusuna istek atar.
       └─► Go, kullanıcıyı RabbitMQ "Interstellar_Bekleyenler" kuyruğuna atar.
       └─► Başlangıç saatini Redis'e yazar (sayaç başlar).

4. Başka bir kullanıcı aynı butona bastığında:
   └─► RabbitMQ iki kullanıcıyı eşleştirir.

5. İki kullanıcı arasında WebSocket bağlantısı kurulur → Özel sohbet odası açılır.

6. Mesajlar anlık gösterilir, asenkron olarak MongoDB'ye kaydedilir.

7. İkisi de "Arkadaş Ekle" derse → MongoDB'deki friends dizisine
   birbirlerinin ID'leri eklenir → Kalıcı arkadaşlık kurulur.
```

---

## 📁 Proje Yapısı (Genel Harita)

```
Movder/                          # Proje kök dizini (aynı zamanda Flutter projesi)
├── lib/                         # Flutter (Dart) — Mobil uygulama kaynak kodu
│   ├── main.dart                # Uygulama giriş noktası → bootstrap()
│   ├── app/                     # Uygulama kabuğu ve DI
│   │   ├── bootstrap.dart       # Servislerin başlatılması
│   │   ├── app.dart             # MovderApp — MaterialApp root widget
│   │   ├── app_scope.dart       # Manuel Dependency Injection (Singleton)
│   │   ├── app_shell_screen.dart # BottomNavigationBar ile ana navigasyon
│   │   └── app_shell_view_model.dart
│   ├── core/                    # Çekirdek altyapı
│   │   ├── base/                # BaseViewModel, Result, AppFailure
│   │   ├── mixins/              # LoadingStateMixin
│   │   ├── network/             # ApiClient (HTTP katmanı)
│   │   ├── services/            # AuthStorageService, MediaPickerService
│   │   ├── theme/               # AppColors, AppTheme
│   │   └── utils/               # Yardımcı fonksiyonlar
│   ├── features/                # Feature-based modüler mimari (MVVM)
│   │   ├── auth/                # Kayıt & Giriş (email/password + JWT)
│   │   ├── home/                # Ana ekran — Eşleşme radarı
│   │   ├── match/               # Eşleşme motoru arayüzü
│   │   ├── chat/                # Sohbet listesi ve detay
│   │   ├── profile/             # Profil, kullanıcı detay, Letterboxd import
│   │   ├── movies/              # Film detay ekranı
│   │   ├── lists/               # Film listeleri (oluşturma, detay)
│   │   ├── notifications/       # Bildirim ekranı
│   │   └── settings/            # Ayarlar (hesap, gizlilik, bildirim, şifre)
│   │   # Her feature modülü şu yapıdadır:
│   │   #   data/
│   │   #     ├── repositories/   # Abstract repository interface
│   │   #     └── services/       # Repository implementasyonu
│   │   #   presentation/
│   │   #     ├── views/          # Ekran widget'ları
│   │   #     └── view_models/    # ChangeNotifier tabanlı ViewModel'ler
│   ├── models/                  # Paylaşılan veri modelleri (movie.dart)
│   ├── screens/                 # Eski ekranlar (kademeli olarak features/'a taşınıyor)
│   ├── services/                # Eski servisler (api_service, chat_service vs.)
│   └── shared/                  # Paylaşılan widget'lar ve modeller
│       ├── models/              # AppUser vb.
│       └── widgets/             # AppButton, AppTextField, EmptyView, ErrorView, LoadingView
├── pubspec.yaml
│
├── backend/                     # Go (Golang) + Gin — API Sunucusu
│   ├── main.go                  # Backend giriş noktası (Gin router setup)
│   ├── config/                  # Veritabanı bağlantıları, env, RabbitMQ manager, Redis, worker pool
│   ├── controllers/             # HTTP handler'lar (user, chat, match, friend, list, status, tmdb, notification, privacy)
│   ├── routes/                  # Route tanımlamaları (userRoutes, chatRoutes, matchRoutes vb.)
│   ├── services/                # İş mantığı (matchmaking.go, tmdb.go)
│   ├── models/                  # Go veri modelleri (user, friend, list, status, import_job)
│   ├── middleware/              # Auth middleware (JWT doğrulama)
│   ├── workers/                 # Arka plan işçileri (csv_worker.go)
│   ├── uploads/                 # Yüklenen dosyalar
│   ├── docker-compose.yml       # MongoDB, Redis, RabbitMQ konteynerlerini ayağa kaldırır
│   ├── go.mod
│   └── go.sum
│
├── CLAUDE.md                    # Bu dosya — Proje rehberi
└── README.md
```

---

## 🚨 Önemli Kurallar ve Dikkat Edilecekler

### ❌ YAPMA:

1. API anahtarlarını (TMDB, Gemini) client tarafına gömme; her zaman backend üzerinden kullan.
2. Kullanıcı şifrelerini veya hassas verileri log'a yazma.
3. WebSocket bağlantılarını doğrulama (auth) olmadan açma.
4. Üzerinde çalışılmayan "AI Eşleşme" özelliğine kod yazma (askıda olan modül).
5. Production ortamında `fmt.Println` kullanma; yapısal loglama (structured logging) tercih et.
6. `git checkout`, `git reset --hard`, `git restore` gibi yerel dosyaların üzerine Git'teki versiyonu yazabilecek komutları **kullanıcıya sormadan otomatik olarak çalıştırma**. Bu tür komutları uygulamadan önce mutlaka kullanıcıya bildir ve onay al.

### ✅ YAP:

1. Commit mesajlarını ve plan içeriklerini **Türkçe** yaz.
2. Her yeni API endpoint'ine **hata yönetimi** (error handling) ekle.
3. MongoDB sorgularında gerekli **indeksleri** oluştur.
4. Redis key'lerinde tutarlı **prefix** ve **TTL** kullan.
5. RabbitMQ kuyruklarında **dead-letter** stratejisi uygula.
6. Flutter tarafında state yönetimini merkezi tut (MVVM: ChangeNotifier + BaseViewModel + AppScope).
7. Docker Compose ile lokal geliştirme ortamını tek komutla ayağa kaldır.
8. Sorulara çözüm önerisi uygularken **overengineering yapma**, sorunu önce iyice anla.
9. "Bu sorunu nasıl çözeriz?" gibi sorularda **öneri sun, doğrudan uygulamaya geçme**.
10. Kod tabanını araştırmadan asla bir dosya hakkında iddialarda bulunma.

---

## 📝 Güncellik

**Son güncelleme:** 2026-04-14

Önemli mimari değişiklikler yapıldığında bu dosyayı güncellemeyi unutma!
