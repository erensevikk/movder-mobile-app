/// Movder uygulamasına özel yasal metinler.
///
/// KVKK Aydınlatma Metni ve Kullanım Şartları burada merkezi olarak tutulur.
/// Güncelleme yapıldığında tek bir dosyadan yönetilir.

class LegalTexts {
  LegalTexts._();

  static const String kvkkText = '''
MOVDER — KİŞİSEL VERİLERİN KORUNMASI HAKKINDA AYDINLATMA METNİ

Son Güncelleme: 14 Nisan 2026

Movder uygulaması ("Uygulama") olarak, 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında veri sorumlusu sıfatıyla kişisel verilerinizi aşağıda açıklanan amaç ve yöntemlerle işlemekteyiz. Bu aydınlatma metni, KVKK'nın 10. maddesi uyarınca bilgilendirme yükümlülüğümüzü yerine getirmek amacıyla hazırlanmıştır.

1. VERİ SORUMLUSU

Movder uygulaması, kişisel verilerinizin işlenmesinde veri sorumlusu sıfatıyla hareket etmektedir.

2. İŞLENEN KİŞİSEL VERİLER

Uygulama kapsamında aşağıdaki kişisel verileriniz işlenmektedir:

• Kimlik Bilgileri: Kullanıcı adı, e-posta adresi, doğum tarihi, şehir bilgisi.
• Hesap Güvenliği Bilgileri: Şifrelenmiş (hash) parola, JWT oturum tokenleri.
• İzleme Verileri: İzlediğiniz veya izleme listenize eklediğiniz film ve dizi bilgileri, Letterboxd'den aktarılan izleme geçmişi, favori film seçimleriniz.
• Eşleşme ve Sosyal Etkileşim Verileri: Anlık izleme durumunuz ("status"), eşleşme geçmişiniz, arkadaşlık bağlantılarınız, gönderdiğiniz ve aldığınız sohbet mesajları.
• Cihaz ve Bağlantı Verileri: IP adresi, oturum süresi, WebSocket bağlantı bilgileri.

3. KİŞİSEL VERİLERİN İŞLENME AMAÇLARI

Kişisel verileriniz aşağıdaki amaçlarla işlenmektedir:

• Hesap oluşturma, kimlik doğrulama ve oturum yönetimi.
• Anlık izleme durumu belirleme ve canlı sayaç sağlama.
• Aynı içeriği izleyen kullanıcılar arasında gerçek zamanlı eşleşme gerçekleştirme.
• Birebir sohbet hizmeti sunma ve mesaj geçmişini saklama.
• Karşılıklı onay ile arkadaşlık bağlantısı kurma.
• TMDB üzerinden film arama, profil ve kütüphane oluşturma.
• Letterboxd CSV dosyası aracılığıyla izleme geçmişi aktarımı.
• Bildirim ve uygulama içi iletişim hizmetleri.
• Hizmet kalitesinin artırılması, hata tespiti ve sistem güvenliğinin sağlanması.

4. KİŞİSEL VERİLERİN AKTARILMASI

Kişisel verileriniz, hizmetin sağlanması amacıyla aşağıdaki taraflara aktarılabilir:

• TMDB (The Movie Database): Film arama ve meta veri sorguları kapsamında, yalnızca arama terimleriniz iletilir; kişisel kimlik bilgileriniz paylaşılmaz.
• Barındırma ve altyapı hizmet sağlayıcıları: Verileriniz şifrelenmiş olarak güvenli sunucularda saklanır.

Kişisel verileriniz, açık rızanız olmaksızın yurt dışına aktarılmaz. TMDB API sorguları anonim nitelikte olup kişisel veri içermez.

5. KİŞİSEL VERİLERİN SAKLANMA SÜRESİ

• Hesap bilgileri: Hesabınız aktif olduğu sürece saklanır.
• Sohbet mesajları: Hesabınız aktif olduğu sürece veya tarafınızca silinene kadar saklanır.
• İzleme durumu (status) verileri: Gerçek zamanlı olarak saklanır ve oturum sona erdiğinde otomatik olarak silinir.
• Hesap silme talebiniz üzerine tüm kişisel verileriniz makul süre içerisinde kalıcı olarak silinir.

6. VERİ GÜVENLİĞİ

Kişisel verilerinizin güvenliğini sağlamak amacıyla aşağıdaki teknik ve idari tedbirler uygulanmaktadır:

• Parolalar, bcrypt algoritması ile tek yönlü olarak şifrelenir; düz metin olarak saklanmaz.
• Oturum yönetimi JWT (JSON Web Token) ile gerçekleştirilir.
• WebSocket bağlantıları kimlik doğrulaması ile korunur.
• Veritabanı erişimleri yetkilendirme mekanizmalarıyla sınırlandırılmıştır.

7. YAŞ SINIRI

Movder uygulamasını kullanabilmek için en az 16 (on altı) yaşında olmanız gerekmektedir. 16 yaşından küçük bireylerin kişisel verileri bilerek işlenmez. Yaş koşulunu sağlamadığı tespit edilen hesaplar bildirim yapılmaksızın silinebilir.

8. KVKK KAPSAMINDAKİ HAKLARINIZ

KVKK'nın 11. maddesi uyarınca aşağıdaki haklara sahipsiniz:

a) Kişisel verilerinizin işlenip işlenmediğini öğrenme,
b) İşlenmişse buna ilişkin bilgi talep etme,
c) İşlenme amacını ve bunların amacına uygun kullanılıp kullanılmadığını öğrenme,
d) Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,
e) Eksik veya yanlış işlenmiş olması hâlinde düzeltilmesini isteme,
f) KVKK'nın 7. maddesinde öngörülen şartlar çerçevesinde silinmesini veya yok edilmesini isteme,
g) İşlenen verilerin münhasıran otomatik sistemler vasıtasıyla analiz edilmesi suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme,
h) Kanuna aykırı olarak işlenmesi sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme.

Bu haklarınızı kullanmak için uygulama içi "Ayarlar > Hesap" bölümünden veya movder.app@gmail.com adresine e-posta göndererek başvurabilirsiniz.

İşbu aydınlatma metni, yasal düzenlemelerdeki değişikliklere paralel olarak güncellenebilir. Güncel metin her zaman uygulama üzerinden erişilebilir olacaktır.
''';

  static const String termsText = '''
MOVDER — KULLANIM ŞARTLARI VE KULLANICI SÖZLEŞMESİ

Son Güncelleme: 14 Nisan 2026

Bu Kullanım Şartları ("Sözleşme"), Movder mobil uygulamasını ("Uygulama") kullanan siz ("Kullanıcı") ile Movder arasındaki ilişkiyi düzenler. Uygulamayı kullanarak işbu Sözleşme'nin tüm hükümlerini kabul etmiş sayılırsınız.

1. HİZMETİN TANIMI

Movder, kullanıcıların o an izledikleri film veya diziyi bildirerek aynı içeriği izleyen diğer kullanıcılarla anlık olarak eşleştirilmesini ve birebir sohbet etmesini sağlayan sosyal bir platformdur. Uygulama ayrıca şu hizmetleri sunar:

• TMDB altyapısı ile film arama ve profil oluşturma.
• Letterboxd CSV dosyasıyla izleme geçmişi aktarımı.
• Film listeleri oluşturma ve paylaşma.
• Karşılıklı onay ile arkadaşlık kurma.

2. HESAP OLUŞTURMA VE YAŞ SINIRI

2.1. Uygulamayı kullanabilmek için geçerli bir e-posta adresi ile hesap oluşturmanız gerekmektedir.

2.2. Uygulamayı kullanabilmek için en az 16 (on altı) yaşında olmanız zorunludur. Kayıt sırasında beyan ettiğiniz doğum tarihi ile yaşınız doğrulanır. Yanlış beyanda bulunan kullanıcıların hesapları bildirim yapılmaksızın askıya alınabilir veya kalıcı olarak silinebilir.

2.3. Hesap bilgilerinizin gizliliğinden ve güvenliğinden siz sorumlusunuz. Şifrenizi üçüncü kişilerle paylaşmamalısınız.

3. KULLANICI YÜKÜMLÜLÜKLERI

Uygulamayı kullanırken aşağıdaki kurallara uymanız zorunludur:

3.1. Sohbet ve etkileşimlerde:
• Hakaret, küfür, aşağılama, taciz veya tehdit içeren mesajlar göndermek yasaktır.
• Nefret söylemi, ırkçılık, cinsiyetçilik, homofobi veya herhangi bir ayrımcılık içeren ifadeler kullanmak yasaktır.
• Cinsel içerikli, müstehcen veya uygunsuz materyal paylaşmak yasaktır.
• Diğer kullanıcıları rahatsız edici, istemci veya spam niteliğinde mesaj göndermek yasaktır.

3.2. Hesap kullanımında:
• Başka bir kişinin kimliğine bürünmek veya yanıltıcı bilgi vermek yasaktır.
• Birden fazla sahte hesap oluşturmak yasaktır.
• Otomatik bot, script veya benzeri otomatik araçlarla uygulamayı kullanmak yasaktır.

3.3. Sistem güvenliğinde:
• Uygulamanın altyapısına zarar vermeye yönelik girişimlerde bulunmak yasaktır.
• Diğer kullanıcıların verilerine yetkisiz erişim sağlamaya çalışmak yasaktır.
• Uygulamayı tersine mühendislik (reverse engineering) yöntemleriyle analiz etmek yasaktır.

4. EŞLEŞME VE SOHBET KURALLARI

4.1. Eşleşme sistemi, aynı içeriği aynı anda izleyen kullanıcıları birebir olarak bir araya getirir. Eşleşme tamamen otomatiktir ve bir eş garantisi verilmez.

4.2. Sohbet odaları eşleşme sonucu oluşturulur. Sohbet içerikleri şifrelenmiş olarak saklanır.

4.3. Arkadaşlık bağlantısı yalnızca karşılıklı onay ile kurulur. Tek taraflı onay arkadaşlık oluşturmaz.

4.4. Uygunsuz davranışta bulunan kullanıcıları bildirebilirsiniz. Bildirilen kullanıcılar inceleme sonucunda uyarılabilir, geçici olarak askıya alınabilir veya kalıcı olarak engellenebilir.

5. İÇERİK VE FİKRİ MÜLKİYET

5.1. Uygulamada görüntülenen film afişleri, özetler ve meta veriler TMDB (The Movie Database) API'si aracılığıyla sağlanmaktadır. Bu içerikler ilgili hak sahiplerine aittir.

5.2. Kullanıcıların oluşturduğu içerikler (listeler, profil bilgileri, mesajlar) kullanıcının kendisine aittir. Ancak hizmeti sağlamak amacıyla bu verilerin işlenmesine izin vermiş sayılırsınız.

5.3. Movder markası, logosu, tasarımı ve yazılımı fikri mülkiyet hakları kapsamında korunmaktadır.

6. SORUMLULUK SINIRLAMALARI

6.1. Movder, kullanıcılar arasındaki iletişimden ve etkileşimlerden doğrudan sorumlu değildir. Kullanıcılar arası anlaşmazlıklarda sorumluluk ilgili taraflara aittir.

6.2. Uygulama "olduğu gibi" sunulmaktadır. Kesintisiz veya hatasız hizmet garantisi verilmez.

6.3. Teknik bakım, güncelleme veya mücbir sebepler nedeniyle hizmette geçici kesintiler yaşanabilir.

6.4. Kullanıcıların Letterboxd'den aktardığı verilerin doğruluğundan Movder sorumlu değildir.

7. HESAP ASKIYA ALMA VE SONLANDIRMA

7.1. İşbu Sözleşme'nin herhangi bir hükmünü ihlal etmeniz durumunda hesabınız geçici veya kalıcı olarak askıya alınabilir.

7.2. Hesabınızı istediğiniz zaman "Ayarlar > Hesap" bölümünden silebilirsiniz. Hesap silme işlemi geri alınamaz ve tüm verileriniz kalıcı olarak silinir.

7.3. 16 yaşından küçük olduğu tespit edilen hesaplar derhal kapatılır.

8. DEĞİŞİKLİKLER

8.1. Bu Sözleşme, Movder tarafından önceden bildirim yapılarak güncellenebilir. Güncellenmiş sözleşme uygulama üzerinden yayımlandığı tarihte yürürlüğe girer.

8.2. Uygulamayı güncelleme sonrasında kullanmaya devam etmeniz, yeni şartları kabul ettiğiniz anlamına gelir.

9. UYGULANACAK HUKUK VE UYUŞMAZLIK ÇÖZÜMÜ

İşbu Sözleşme Türkiye Cumhuriyeti hukukuna tabidir. Sözleşme'den doğabilecek uyuşmazlıklarda Türkiye Cumhuriyeti mahkemeleri ve icra daireleri yetkilidir.

10. İLETİŞİM

Sözleşme ile ilgili sorularınız veya geri bildirimleriniz için movder.app@gmail.com adresine e-posta gönderebilirsiniz.

Bu Sözleşme'yi kabul ederek yukarıdaki tüm koşulları okuduğunuzu, anladığınızı ve kabul ettiğinizi beyan etmiş olursunuz.
''';
}
