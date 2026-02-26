import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/movie.dart';
import 'services/api_service.dart';
import 'screens/movie_detail_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const MovderApp());
}

class MovderApp extends StatelessWidget {
  const MovderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Movder',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.redAccent,
      ),
      home: const MainNavigatorScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ANA MENÜ: BOTTOM NAVIGATION SARMALAYICISI
// ─────────────────────────────────────────────────────────────
class MainNavigatorScreen extends StatefulWidget {
  const MainNavigatorScreen({super.key});

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const MovieRadarScreen(), // Film Radar sayfası artık Anasayfa oldu
    const Center(
        child: Text("Eşleşme Ara (Yakında)",
            style: TextStyle(color: Colors.white, fontSize: 18))),
    const Center(
        child: Text("Sohbetler",
            style: TextStyle(color: Colors.white))), // TODO: Chat Screen
    const ProfileScreen(), // Yeni kodlanan Profil/Hesabım ekranı
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F0F0F),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType
            .fixed, // 3'ten fazla eleman olunca isimlerin kaybolmaması için
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: "Anasayfa",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: "Eşleşme Ara",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Mesajlar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Hesabım",
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KAYIT EKRANI
// ─────────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('http://10.0.2.2:8080/register');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usernameController.text,
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _showSnackBar("Başarılı! ID: ${data['userId']}", Colors.green);
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? "Bir hata oluştu", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Sunucuya ulaşılamadı. Go açık mı?", Colors.orange);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.movie_filter, color: Colors.redAccent, size: 60),
              const SizedBox(height: 20),
              const Text("Movder'a\nHoş Geldin",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 10),
              const Text("Sinema tutkunlarıyla eşleşmeye hazır mısın?",
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 50),
              _buildTextField(
                  _usernameController, "Kullanıcı Adı", Icons.person_outline),
              const SizedBox(height: 20),
              _buildTextField(
                  _emailController, "E-posta", Icons.email_outlined),
              const SizedBox(height: 20),
              _buildTextField(_passwordController, "Şifre", Icons.lock_outline,
                  isObscure: true),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Kayıt Ol",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.redAccent),
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ANA EKRAN — GERÇEK TMDB VERİLERİYLE FİLM RADAR
// ─────────────────────────────────────────────────────────────
class MovieRadarScreen extends StatefulWidget {
  const MovieRadarScreen({super.key});

  @override
  State<MovieRadarScreen> createState() => _MovieRadarScreenState();
}

class _MovieRadarScreenState extends State<MovieRadarScreen> {
  List<Movie> _trendingMovies = [];
  List<Movie> _mindfuckMovies = [];
  List<Movie> _exMovies = [];
  List<Movie> _horrorMovies = [];
  List<Movie> _indieMovies = [];
  List<Movie> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;
  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    // Tüm kategorileri paralel olarak çek
    final results = await Future.wait([
      ApiService.getTrending(),
      ApiService.getDiscoverMovies(
          '878,9648'), // Bilim Kurgu & Gizem (Beyin Yakanlar)
      ApiService.getDiscoverMovies(
          '10749,18'), // Romantik & Dram (Eski Sevgiliyi Hatırlatanlar)
      ApiService.getDiscoverMovies('27,53'), // Korku & Gerilim
      ApiService.getDiscoverMovies(
          '10402,36'), // Müzik & Tarih vs Indie konsepti
    ]);

    if (mounted) {
      setState(() {
        _trendingMovies = results[0];
        _mindfuckMovies = results[1];
        _exMovies = results[2];
        _horrorMovies = results[3];
        _indieMovies = results[4];
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {}); // X ikonunun görünürlüğünü güncellemek için
    _debounce?.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      final results = await ApiService.searchMovies(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSearchQuery = _searchController.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Ne izliyorsun?",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon:
                          const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _onSearchChanged("");
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : hasSearchQuery
              ? _buildSearchResults()
              : _buildTrendingView(),
    );
  }

  // ── ARAMA SONUÇLARI ────────────────────────────────────────
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.redAccent));
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey, size: 60),
            SizedBox(height: 12),
            Text("Sonuç bulunamadı",
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildSearchResultCard(_searchResults[index]);
      },
    );
  }

  Widget _buildSearchResultCard(Movie movie) {
    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailScreen(movie: movie),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(14)),
                child: movie.posterUrl.isNotEmpty
                    ? Image.network(
                        movie.posterUrl,
                        width: 90,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 130,
                          color: const Color(0xFF2A2A2A),
                          child: const Icon(Icons.movie, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 90,
                        height: 130,
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(Icons.movie, color: Colors.grey),
                      ),
              ),
              // Film Bilgileri
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (movie.releaseYear.isNotEmpty)
                        Text(
                          movie.releaseYear,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        movie.genreNames,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            movie.voteAverage.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        movie.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  // ── TREND FİLMLER (ANA SAYFA) ──────────────────────────────
  Widget _buildTrendingView() {
    // Trend filmleri 10'arlık gruplara böl
    final List<Movie> topTrending = _trendingMovies.take(10).toList();
    final List<Movie> restTrending =
        _trendingMovies.length > 10 ? _trendingMovies.sublist(10) : [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildCategory("🔴 Şu An Popüler", topTrending),
          if (restTrending.isNotEmpty)
            _buildCategory("🎬 Daha Fazla Keşfet", restTrending),
          _buildCategory("🌌 Bilim Kurgu & Gizem", _mindfuckMovies),
          _buildCategory("💔 Dram & Romantik", _exMovies),
          _buildCategory("🩸 Korku & Gerilim", _horrorMovies),
          _buildCategory("🍿 Müzik & Tarih", _indieMovies),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, List<Movie> movies) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return _buildMovieCard(movies[index]);
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailScreen(movie: movie),
            ),
          );
        },
        child: Container(
          width: 135,
          margin: const EdgeInsets.only(right: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Afiş görseli
                movie.posterUrl.isNotEmpty
                    ? Image.network(
                        movie.posterUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFF1E1E1E),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.redAccent, strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey, size: 40),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(Icons.movie,
                            color: Colors.grey, size: 40),
                      ),
                // Alt karartma gradyanı
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.88),
                      ],
                    ),
                  ),
                ),
                // Puan rozeti (sol üst)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 10, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          movie.voteAverage.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Canlı İzleyici Rozeti (Sağ üst)
                if (movie.watcherCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.72),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.8), width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${movie.watcherCount} İzliyor",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Film adı + yıl (sol alt)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        movie.releaseYear,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
