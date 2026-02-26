import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // TODO: Auth integration (using a mock value for now)
  final bool _isLoggedIn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _isLoggedIn ? _buildAuthenticatedProfile() : _buildGuestProfile(),
    );
  }

  /// Misafir Görünümü (Giriş Yapılmamış)
  Widget _buildGuestProfile() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Arkaplan: Film Kolajı veya Düz Renk (Şimdilik Network Image)
        Image.network(
          'https://image.tmdb.org/t/p/w780/xbiycuc84TrieEWwkkuH2hoEa9S.jpg', // Örnek olarak Interstellar arkaplanı
          fit: BoxFit.cover,
        ),
        // Blur Efekti
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        // İçerik
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.movie_filter_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Yalnız İzleme.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Frekansına uygun kişilerle anında eşleş ve film zevkini sergile.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Giriş Yap ekranına yönlendir
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Giriş Yap",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Kayıt Ol ekranına yönlendir
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Kayıt Ol",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Profil Header (Auth Durumu: Giriş Yapılmış)
  Widget _buildAuthenticatedProfile() {
    return CustomScrollView(
      slivers: [
        _buildProfileAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsBar(),
                const SizedBox(height: 40),
                _buildFavoriteMoviesSection(),
                const SizedBox(height: 40),
                _buildActionButtons(),
                const SizedBox(height: 40),
                _buildSettingsList(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAppBar() {
    return SliverAppBar(
      expandedHeight: 280.0,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F0F),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Favori film banner arkaplanı (Örnek)
            Image.network(
              'https://image.tmdb.org/t/p/w780/2ssWTSVklAEc98frZUQhgtGHx7s.jpg',
              fit: BoxFit.cover,
            ),
            // Karartma efekti
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF0F0F0F)],
                  stops: [0.3, 1.0],
                ),
              ),
            ),
            // Avatar ve Kullanıcı Bilgisi
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 3),
                      image: const DecorationImage(
                        image: NetworkImage(
                            'https://api.dicebear.com/7.x/avataaars/png?seed=MovderUser'), // Rastgele avatar
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Eren Yılmaz", // Örnek isim
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Sinema Aşığı",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Profil düzenleme
                    },
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem("14", "Eşleşmeler"),
          _buildDivider(),
          _buildStatItem("128", "İzlenenler"),
          _buildDivider(),
          _buildStatItem("6", "Listeler"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white24,
    );
  }

  Widget _buildFavoriteMoviesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Favori 4 Film",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMovieSlot(
                'https://image.tmdb.org/t/p/w500/xbiycuc84TrieEWwkkuH2hoEa9S.jpg'),
            _buildMovieSlot(
                'https://image.tmdb.org/t/p/w500/8c4a8kE7PizaGQQnditMmI1xbRp.jpg'),
            _buildEmptyMovieSlot(),
            _buildEmptyMovieSlot(),
          ],
        ),
      ],
    );
  }

  Widget _buildMovieSlot(String posterUrl) {
    return Container(
      width: 75,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: NetworkImage(posterUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMovieSlot() {
    return GestureDetector(
      onTap: () {
        // TODO: Film arama bottom sheet'i aç
      },
      child: Container(
        width: 75,
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.white24, width: 1.5, style: BorderStyle.solid),
          color: const Color(0xFF1E1E1E),
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: Colors.white54,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            // TODO: Listeler sayfasına yönlendir
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white12),
            ),
            elevation: 0,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_special,
                    color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Koleksiyonum / Listelerim",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E1E1E),
                const Color(0xFF2C3E50).withOpacity(0.4),
              ],
            ),
          ),
          child: ElevatedButton(
            onPressed: () {
              // TODO: Letterboxd İçe Aktarma mantığı
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    BorderSide(color: const Color(0xFF4A90E2).withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sync_rounded,
                      color: Color(0xFF4A90E2), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Letterboxd'dan İçe Aktar",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "CSV dosyanı yükle",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSettingsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hesap",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildListTile(Icons.settings_outlined, "Ayarlar"),
        _buildListTile(Icons.privacy_tip_outlined, "Gizlilik"),
        _buildListTile(Icons.notifications_none_rounded, "Bildirimler"),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text("Çıkış Yap",
              style: TextStyle(color: Colors.redAccent)),
          onTap: () {
            // TODO: Logout işlemi
          },
        ),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String title) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white30),
      onTap: () {
        // TODO: Navigasyon
      },
    );
  }
}
