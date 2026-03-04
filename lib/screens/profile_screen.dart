import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'login_screen.dart';
import 'user_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  String _username = '';
  String _avatarUrl = '';
  String _coverUrl = ''; // Kullanıcının kapak fotoğu
  String _favoritePosterUrl = ''; // Favori listenin ilk film posteri (fallback)

  // İzleme durumu
  bool _isWatching = false;
  String _watchingMovieName = '';
  String _watchingFor = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    final loggedIn = AuthService.isLoggedIn;
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
      return;
    }

    final profile = await ApiService.getProfile();
    if (!mounted) return;

    if (profile == null) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
      return;
    }

    // İzleme durumunu çek
    final statusData = await ApiService.getMyWatchStatus();
    if (!mounted) return;

    setState(() {
      _isLoggedIn = true;
      _username = (profile['username'] ?? '').toString();
      _avatarUrl = (profile['avatarUrl'] ?? '').toString();
      _coverUrl = (profile['coverUrl'] ?? '').toString();

      if (statusData != null && statusData['watching'] == true) {
        _isWatching = true;
        final status = statusData['status'];
        _watchingMovieName = (status?['movieName'] ?? '').toString();
        _watchingFor = (statusData['watchingFor'] ?? '').toString();
      } else {
        _isWatching = false;
        _watchingMovieName = '';
        _watchingFor = '';
      }

      _isLoading = false;
    });

    // Kapak yoksa favori listeden poster çek
    if (_coverUrl.isEmpty) {
      final lists = await ApiService.getMyLists();
      if (!mounted) return;
      for (final list in lists) {
        final name = (list['name'] ?? '').toString().toLowerCase();
        if (name.contains('favori')) {
          final id = list['id'] ?? list['_id'];
          if (id != null) {
            final items = await ApiService.getListItems(id.toString());
            if (items.isNotEmpty) {
              for (final item in items) {
                final poster = item['posterUrl']?.toString() ?? '';
                if (poster.isNotEmpty) {
                  if (mounted) {
                    setState(() {
                      _favoritePosterUrl = poster.startsWith('http')
                          ? poster
                          : 'https://image.tmdb.org/t/p/w780$poster';
                    });
                  }
                  break; // İlk posteri bulur bulmaz döngüyü kır
                }
              }
            }
          }
          break; // Sadece favori listesini taramak yeterli
        }
      }
    }
  }

  /// Sadece izleme durumunu anlık olarak (API'den) günceller.
  Future<void> reloadWatchingStatus() async {
    final statusData = await ApiService.getMyWatchStatus();
    if (!mounted) return;

    setState(() {
      if (statusData != null && statusData['watching'] == true) {
        _isWatching = true;
        final status = statusData['status'];
        _watchingMovieName = (status?['movieName'] ?? '').toString();
        _watchingFor = (statusData['watchingFor'] ?? '').toString();
      } else {
        _isWatching = false;
        _watchingMovieName = '';
        _watchingFor = '';
      }
    });
  }

  /// Tam ekran fotoğraf görüntüleyici
  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white38, size: 64),
                  ),
                ),
              ),
              Positioned(
                top: 48,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.clearToken();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _isLoggedIn ? _buildAuthenticatedProfile() : _buildGuestProfile(),
    );
  }

  Widget _buildGuestProfile() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          'https://image.tmdb.org/t/p/w780/xbiycuc84TrieEWwkkuH2hoEa9S.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(color: const Color(0xFF0F0F0F)),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent,
                        Colors.redAccent.shade700,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.movie_filter_rounded,
                      color: Colors.white, size: 30),
                ),

                const SizedBox(height: 20),

                // Başlık
                const Text(
                  'Movder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 8),

                // Alt başlık
                Text(
                  'Yalnız izleme devri bitti.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                // Tanıtım yazısı
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    'Movder, aynı anda aynı filmi izleyen insanları '
                    'anlık olarak eşleştiren bir sosyal sinema platformudur. '
                    'Bir film açtığında, o filmi izleyen başka biriyle '
                    'saniyeler içinde buluş ve birlikte keyfini çıkar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Özellik kartları
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        Icons.bolt_rounded,
                        'Anlık Eşleşme',
                        'Aynı filmi izleyenle saniyede buluş',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildFeatureCard(
                        Icons.chat_bubble_rounded,
                        'Canlı Sohbet',
                        'Film hakkında anında tartış',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        Icons.people_rounded,
                        'Arkadaşlık',
                        'Film zevkine uygun kişileri keşfet',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildFeatureCard(
                        Icons.movie_creation_rounded,
                        'Film Profili',
                        'İzleme geçmişini sergile',
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Giriş Yap Butonu
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 8,
                      shadowColor: Colors.redAccent.withValues(alpha: 0.4),
                    ),
                    child: const Text(
                      'Giriş Yap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Kayıt Ol Butonu
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Kayıt Ol',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.redAccent, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedProfile() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildTwitterStyleHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActionButtons(),
                const SizedBox(height: 16),
                _buildLetterboxdSyncButton(),
                const SizedBox(height: 32),
                _buildSettingsList(),
                const SizedBox(height: 32),
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLetterboxdSyncButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const UserDetailScreen(
                userId: '',
                isMe: true,
                openImportOnStart: true,
              ),
            ),
          ).then((_) => _loadProfile());
        },
        icon:
            const Icon(Icons.sync_rounded, color: Color(0xFF40BCF4), size: 20),
        label: const Text(
          'Letterboxd Verilerini İçe Aktar',
          style: TextStyle(
            color: Color(0xFF40BCF4),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF2C3440)),
          backgroundColor: const Color(0xFF141A1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        label: const Text(
          'Çıkış Yap',
          style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AYARLAR',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingsItem(Icons.person_outline, 'Hesap'),
        _buildSettingsItem(Icons.notifications_none, 'Bildirimler'),
        _buildSettingsItem(Icons.lock_outline, 'Gizlilik'),
        _buildSettingsItem(Icons.help_outline, 'Yardım ve Destek'),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title ekranı yakında eklenecek')),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROFİL',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UserDetailScreen(
                    userId:
                        '', // Kendi profilimiz olduğundan userId opsiyonel (veya isMe: true) için boş verebiliriz ama api istiyorsa doldur. Şimdilik isMe true veriyoruz
                    isMe: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_search_rounded, color: Colors.white),
            label: const Text(
              'Profilimi Görüntüle',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwitterStyleHeader() {
    const double coverHeight = 100.0;
    const double avatarSize = 88.0;

    return Container(
      color: const Color(0xFF0F0F0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Stack boyutunu belirleyen görünmez alan
              const SizedBox(
                width: double.infinity,
                height: coverHeight + (avatarSize / 2),
              ),
              // Kapak fotoğı: kullanıcı kapak > favori poster > sabit fallback
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: coverHeight,
                child: () {
                  final String url = _coverUrl.isNotEmpty
                      ? (_coverUrl.startsWith('http')
                          ? _coverUrl
                          : '${ApiService.baseUrl}$_coverUrl')
                      : _favoritePosterUrl.isNotEmpty
                          ? _favoritePosterUrl
                          : 'https://image.tmdb.org/t/p/w780/2ssWTSVklAEc98frZUQhgtGHx7s.jpg';
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFF1E1E1E)),
                  );
                }(),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: coverHeight,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              ),
              // Avatar — artık Stack sınırları İÇİNDE
              Positioned(
                left: 20,
                bottom: 0,
                child: GestureDetector(
                  onTap: _avatarUrl.isNotEmpty
                      ? () => _showFullScreenImage(
                          '${ApiService.baseUrl}$_avatarUrl')
                      : null,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E1E),
                      border:
                          Border.all(color: const Color(0xFF0F0F0F), width: 4),
                      image: _avatarUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(
                                  '${ApiService.baseUrl}$_avatarUrl'),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white54,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const SizedBox(height: 6),
                _buildWatchingStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchingStatus() {
    if (!_isWatching || _watchingMovieName.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2318),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1A4A2E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Çevrimiçi',
                style: TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$_watchingMovieName izliyor — $_watchingFor',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
