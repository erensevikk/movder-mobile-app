import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../settings_screen.dart';
import '../user_detail_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const String _supportEmail = 'support@movder.app';
  static const String _appVersion = '1.0.0+1';

  final GlobalKey _faqSectionKey = GlobalKey();

  String _selectedCategoryId = 'all';
  String _username = '';

  late final List<_HelpCategory> _categories = _buildCategories();

  @override
  void initState() {
    super.initState();
    _loadProfileSummary();
  }

  Future<void> _loadProfileSummary() async {
    final profile = await ApiService.getProfile();
    if (!mounted || profile == null) return;

    setState(() {
      _username = (profile['username'] ?? '').toString();
    });
  }

  List<_HelpCategory> _buildCategories() {
    return [
      _HelpCategory(
        id: 'match',
        title: 'Eşleşme Sorunları',
        subtitle: 'Eşleşme bulunmaması, şehir filtresi ve onay ekranı',
        icon: Icons.local_fire_department_outlined,
        faqs: [
          _HelpFaq(
            title: 'Eşleşme arıyorum ama kimse çıkmıyor',
            description:
                'Movder önce aynı filmi izleyen bir kullanıcı bulmaya çalışır. Kuyrukta uygun biri yoksa eşleşme oluşmaz.',
            steps: const [
              'Önce gerçekten bir filmi veya diziyi izliyor olarak görünür durumda olduğundan emin ol.',
              'Aynı anda aynı içeriği izleyen kullanıcı yoksa eşleşme gelmeyebilir.',
              'Şehrimde Eşleşme Ara açıksa eşleşme için şehir bilgisi de aynı olmalıdır.',
              'Eşleşme ekranını kapatıp yeniden açarak kuyruğa tekrar girmeyi dene.',
            ],
          ),
          _HelpFaq(
            title: 'Şehrimde Eşleşme Ara nasıl çalışır?',
            description:
                'Bu modda sistem hem aynı filmi izleyen hem de profilinde aynı şehir seçili olan kullanıcıları eşleştirir.',
            steps: const [
              'Kendi profilindeki şehir bilgisinin doğru olduğundan emin ol.',
              'Karşı taraf da aynı filmi izliyor ve aynı şehirde olmalıdır.',
              'Farklı şehirdeki kullanıcılar bu modda eşleşmez.',
            ],
          ),
          _HelpFaq(
            title: 'Eşleşme modalı açıldı ama sohbet başlamadı',
            description:
                'Sohbetin açılması için iki tarafın da eşleşmeyi kabul etmesi gerekir.',
            steps: const [
              'Karşı tarafın kabul edip etmediğini bekle.',
              'Kabul ettiysen süre dolsa bile sistem karşı tarafın cevabını bekler.',
              'Yine de sohbet açılmıyorsa eşleşme ekranından tekrar kuyruğa gir.',
            ],
          ),
        ],
      ),
      _HelpCategory(
        id: 'chat',
        title: 'Sohbet ve Mesajlar',
        subtitle: 'Mesaj gönderme, sohbet durumu ve sohbet silme',
        icon: Icons.chat_bubble_outline,
        faqs: [
          _HelpFaq(
            title: 'Neden mesaj gönderemiyorum?',
            description:
                'Eşleşme iptal edilmişse veya oda artık aktif değilse sohbet yazma alanı kapanır.',
            steps: const [
              'Sohbet ekranının altında eşleşme iptaliyle ilgili bir uyarı olup olmadığını kontrol et.',
              'Eşleşme iptal edildiyse artık yeni mesaj gönderilemez.',
              'Geçici bağlantı sorunu varsa sohbetten çıkıp tekrar gir.',
            ],
          ),
          _HelpFaq(
            title: 'Sohbeti sildim, karşı tarafın sohbeti de silinir mi?',
            description:
                'Hayır. Sohbeti silmek sadece senin sohbetler listendeki görünürlüğü kaldırır.',
            steps: const [
              'Sola kaydırıp çöp kutusuna bastığında sohbet sadece kendi listenden gizlenir.',
              'Karşı tarafın sohbet ekranı ve geçmişi bundan etkilenmez.',
            ],
          ),
          _HelpFaq(
            title: 'Sohbet listem neden güncellenmiyor?',
            description:
                'Sohbet listesi yeni mesajlara ve oda durumuna göre yenilenir. Ağ veya WebSocket bağlantısı koparsa gecikme yaşanabilir.',
            steps: const [
              'Sohbetler ekranından çıkıp tekrar gir.',
              'İnternet bağlantını kontrol et.',
              'Sorun sürerse uygulamayı yeniden başlat.',
            ],
          ),
        ],
      ),
      _HelpCategory(
        id: 'friends_notifications',
        title: 'Arkadaşlık ve Bildirimler',
        subtitle: 'Arkadaşlık istekleri, bildirimler ve silme işlemleri',
        icon: Icons.notifications_active_outlined,
        faqs: [
          _HelpFaq(
            title: 'Arkadaşlık isteği nasıl gönderilir veya iptal edilir?',
            description:
                'Arkadaşlık işlemleri sohbet ekranı üstünden yönetilir.',
            steps: const [
              'Sohbet ekranındaki Arkadaş Ekle butonuna basarak istek gönder.',
              'İstek gönderildiyse aynı alan İsteği İptal Et olarak görünür.',
              'Karşı taraf kabul veya reddet yaptığında durum anlık güncellenir.',
            ],
          ),
          _HelpFaq(
            title: 'Bildirimler neden gelmiyor?',
            description:
                'Bildirim ayarların kapalıysa yeni eşleşme, mesaj veya arkadaşlık isteği bildirimleri gelmeyebilir.',
            steps: const [
              'Bildirimlere İzin Ver ayarının açık olduğundan emin ol.',
              'Yeni Mesajlar, Yeni Eşleşmeler ve Arkadaşlık İstekleri seçeneklerini kontrol et.',
              'Uygulama içi ses ve titreşim ayarlarını ayrıca gözden geçir.',
            ],
            actionLabel: 'Bildirim Ayarlarını Aç',
            actionType: _HelpActionType.notifications,
          ),
          _HelpFaq(
            title: 'Bildirimi nasıl silerim?',
            description:
                'Bildirimler ekranında kartı sola kaydırarak çöp kutusunu açabilirsin.',
            steps: const [
              'Bildirimi sola kaydır.',
              'Sağdaki çöp kutusuna bas.',
              'Bildirim sadece senin listenden kaldırılır.',
            ],
          ),
        ],
      ),
      _HelpCategory(
        id: 'profile_privacy',
        title: 'Profil, Gizlilik ve Hesap',
        subtitle: 'Profil görünürlüğü, hesap ayarları ve engellenen kullanıcılar',
        icon: Icons.shield_outlined,
        faqs: [
          _HelpFaq(
            title: 'Profilimde bazı alanlar neden görünmüyor?',
            description:
                'Gizlilik ayarlarında profil detaylarını sadece arkadaşlara açık yaptıysan diğer kullanıcılar bu alanları göremez.',
            steps: const [
              'Gizlilik ekranındaki Profil ve Listeler ayarını kontrol et.',
              'Sadece Arkadaşlar seçiliyse profil detayların herkese açık olmaz.',
              'Aktif izleme görünürlüğü ayrı bir ayardır; onu da ayrıca değiştirebilirsin.',
            ],
            actionLabel: 'Gizlilik Ayarlarını Aç',
            actionType: _HelpActionType.privacy,
          ),
          _HelpFaq(
            title: 'Şifremi değiştiremiyorum',
            description:
                'Yeni şifrenin kayıt ekranındaki kurallarla aynı doğrulamadan geçmesi gerekir.',
            steps: const [
              'Mevcut şifreni doğru girdiğinden emin ol.',
              'Yeni şifre en az 6 karakter olmalı.',
              'Yeni şifre en az 1 büyük harf içermeli.',
              'Yeni şifre tekrar alanı aynı olmalıdır.',
            ],
            actionLabel: 'Hesap Ayarlarını Aç',
            actionType: _HelpActionType.account,
          ),
          _HelpFaq(
            title: 'Engellenen kullanıcıları nasıl yönetirim?',
            description:
                'Engellediğin kullanıcıları gizlilik ekranından görebilir ve engeli kaldırabilirsin.',
            steps: const [
              'Gizlilik ekranını aç.',
              'Engellenen Kullanıcılar bölümüne gir.',
              'İstersen engeli kaldır.',
            ],
            actionLabel: 'Gizlilik Ayarlarını Aç',
            actionType: _HelpActionType.privacy,
          ),
        ],
      ),
      _HelpCategory(
        id: 'letterboxd',
        title: 'Letterboxd ve İçe Aktarma',
        subtitle: 'ZIP/CSV içe aktarma, listeler ve favori filmler',
        icon: Icons.sync_alt_outlined,
        faqs: [
          _HelpFaq(
            title: 'Letterboxd verileri nasıl içe aktarılır?',
            description:
                'İçe aktarma işlemi profil ekranındaki Letterboxd aksiyonu üzerinden başlatılır.',
            steps: const [
              'Profilinden Letterboxd Verilerini İçe Aktar alanını aç.',
              'ZIP veya CSV dosyanı seç.',
              'Önizlemeyi kontrol edip uygun içe aktarma seçeneğini tamamla.',
            ],
            actionLabel: 'Letterboxd İçe Aktar',
            actionType: _HelpActionType.importLetterboxd,
          ),
          _HelpFaq(
            title: 'ZIP veya CSV neden yüklenemiyor?',
            description:
                'Dosya biçimi bozuksa, içerik boşsa veya desteklenmeyen bir export yüklenirse önizleme başarısız olabilir.',
            steps: const [
              'Dosyanın gerçekten Letterboxd export dosyası olduğundan emin ol.',
              'Dosyayı yeniden dışa aktarıp tekrar dene.',
              'ZIP içindeki CSV dosyalarının eksik olmadığını kontrol et.',
            ],
          ),
          _HelpFaq(
            title: 'Favori filmlerimi ve listelerimi nasıl düzenlerim?',
            description:
                'Profil ekranında favori filmler ve listeler alanı düzenlenebilir.',
            steps: const [
              'Profilimi Görüntüle ekranını aç.',
              'Listeyi Düzenle alanlarını kullan.',
              'İstersen yeni liste oluşturup film ekleyebilirsin.',
            ],
            actionLabel: 'Profilimi Aç',
            actionType: _HelpActionType.profile,
          ),
        ],
      ),
    ];
  }

  List<_HelpFaq> get _visibleFaqs {
    if (_selectedCategoryId == 'all') {
      return _categories.expand((category) => category.faqs).toList();
    }
    final category = _categories.where((c) => c.id == _selectedCategoryId);
    if (category.isEmpty) return [];
    return category.first.faqs;
  }

  String get _platformLabel {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  Future<void> _openHelpAction(_HelpActionType actionType) async {
    switch (actionType) {
      case _HelpActionType.notifications:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NotificationSettingsScreen(),
          ),
        );
        break;
      case _HelpActionType.privacy:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PrivacySettingsScreen(),
          ),
        );
        break;
      case _HelpActionType.account:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        );
        break;
      case _HelpActionType.profile:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UserDetailScreen(
              userId: '',
              isMe: true,
            ),
          ),
        );
        break;
      case _HelpActionType.importLetterboxd:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UserDetailScreen(
              userId: '',
              isMe: true,
              openImportOnStart: true,
            ),
          ),
        );
        break;
    }
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _faqSectionKey.currentContext;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _copySupportEmail() async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Destek e-postası panoya kopyalandı.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Yardım ve Destek',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildIntroCard(),
          const SizedBox(height: 20),
          _buildSectionHeader('Yardım Kategorileri'),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 12),
          ..._categories.map(_buildCategoryCard),
          const SizedBox(height: 20),
          Container(key: _faqSectionKey, child: _buildFaqSection()),
          const SizedBox(height: 20),
          _buildContactCard(),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withValues(alpha: 0.12),
            const Color(0xFF1E1E1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Movder ile ilgili en sık karşılaşılan sorunlar ve çözüm adımları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Bu ekran; eşleşme, sohbet, bildirim, gizlilik ve Letterboxd içe aktarma akışlarında hızlıca çözüm bulman için hazırlandı.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip('all', 'Tümü'),
          const SizedBox(width: 8),
          ..._categories.expand((category) => [
                _buildCategoryChip(category.id, category.title),
                const SizedBox(width: 8),
              ]),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => _selectCategory(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.redAccent.withValues(alpha: 0.18)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? Colors.redAccent.withValues(alpha: 0.45)
                : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(_HelpCategory category) {
    final isSelected = _selectedCategoryId == category.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectCategory(category.id),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Colors.redAccent.withValues(alpha: 0.42)
                    : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.redAccent.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    color: isSelected ? Colors.redAccent : Colors.white70,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.subtitle,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${category.faqs.length}',
                  style: TextStyle(
                    color: isSelected ? Colors.redAccent : Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    final title = _selectedCategoryId == 'all'
        ? 'Sık Sorulan Sorular'
        : '${_categories.firstWhere((category) => category.id == _selectedCategoryId, orElse: () => _categories.first).title} • Sık Sorulan Sorular';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 12),
        if (_visibleFaqs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'Bu kategori için henüz yardım içeriği bulunmuyor.',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._visibleFaqs.map(_buildFaqTile),
      ],
    );
  }

  Widget _buildFaqTile(_HelpFaq faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white38,
          title: Text(
            faq.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              faq.description,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          children: [
            const SizedBox(height: 4),
            ...faq.steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          size: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (faq.actionLabel != null && faq.actionType != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openHelpAction(faq.actionType!),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.32),
                    ),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(faq.actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bize Ulaşın',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sorunun devam ediyorsa bize yaz. Destek ekibiyle paylaşmak için e-posta adresini kopyalayabilirsin.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.redAccent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    _supportEmail,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _copySupportEmail,
                  child: const Text('Kopyala'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Uygulama Sürümü', _appVersion),
          _buildInfoRow('Platform', _platformLabel),
          if (_username.isNotEmpty) _buildInfoRow('Kullanıcı', _username),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_HelpFaq> faqs;

  const _HelpCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.faqs,
  });
}

class _HelpFaq {
  final String title;
  final String description;
  final List<String> steps;
  final String? actionLabel;
  final _HelpActionType? actionType;

  const _HelpFaq({
    required this.title,
    required this.description,
    required this.steps,
    this.actionLabel,
    this.actionType,
  });
}

enum _HelpActionType {
  notifications,
  privacy,
  account,
  profile,
  importLetterboxd,
}
