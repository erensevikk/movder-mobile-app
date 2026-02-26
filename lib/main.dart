import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      home: const MovieRadarScreen(),
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
        _showSnackBar("Bir hata oluştu: ${response.body}", Colors.red);
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
// ANA EKRAN — KATEGORİLİ FİLM RADAR
// ─────────────────────────────────────────────────────────────
class MovieRadarScreen extends StatelessWidget {
  const MovieRadarScreen({super.key});

  // Yardımcı: Film listesi tanımları
  static final List<Map<String, dynamic>> _trending = [
    {
      "title": "Titanic",
      "poster":
          "https://image.tmdb.org/t/p/w500/9xj7rB6RdrNE02tgnvU9Gv3df5S.jpg",
      "watchers": 1240,
      "platform": "Netflix"
    },
    {
      "title": "Interstellar",
      "poster":
          "https://image.tmdb.org/t/p/w500/gEU2QniE6EJBQwOQvIn9qQp2pZp.jpg",
      "watchers": 850,
      "platform": "Disney+"
    },
    {
      "title": "The Dark Knight",
      "poster":
          "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDp9QmSbmvQv2GqQpS7.jpg",
      "watchers": 620,
      "platform": "Prime"
    },
    {
      "title": "Inception",
      "poster":
          "https://image.tmdb.org/t/p/w500/oYuEqDPkEKJ5FhK1S9J4A9Xj0f.jpg",
      "watchers": 780,
      "platform": "Netflix"
    },
    {
      "title": "Pulp Fiction",
      "poster":
          "https://image.tmdb.org/t/p/w500/d5iIlFn5s0ImszYzBMiV9mz8oIr.jpg",
      "watchers": 550,
      "platform": "Prime"
    },
  ];

  static final List<Map<String, dynamic>> _newReleases = [
    {
      "title": "Dune: Part Two",
      "poster":
          "https://image.tmdb.org/t/p/w500/1pdfLvkbYGDYgc1f2h5tdrKmkC.jpg",
      "watchers": 980,
      "platform": "Max"
    },
    {
      "title": "Oppenheimer",
      "poster":
          "https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0mDGukH2x2c5G0u6x.jpg",
      "watchers": 720,
      "platform": "Prime"
    },
    {
      "title": "Barbie",
      "poster":
          "https://image.tmdb.org/t/p/w500/iuFNMS8U5s6Y82otCoYFh6vWz8x.jpg",
      "watchers": 650,
      "platform": "Netflix"
    },
    {
      "title": "Killers of the Flower Moon",
      "poster":
          "https://image.tmdb.org/t/p/w500/dB6Krk806fZQp2tiNYhpQ9ZUKX6.jpg",
      "watchers": 480,
      "platform": "Apple TV+"
    },
  ];

  static final List<Map<String, dynamic>> _nightMood = [
    {
      "title": "Spider-Man: Across the Spider-Verse",
      "poster":
          "https://image.tmdb.org/t/p/w500/8Vt6mWEReuy4Ofc6dqK5XjNkQYd.jpg",
      "watchers": 500,
      "platform": "Disney+"
    },
    {
      "title": "Guardians of the Galaxy Vol. 3",
      "poster":
          "https://image.tmdb.org/t/p/w500/r2J02Z2OpqeVEcQ8A7DkYxLGfNk.jpg",
      "watchers": 420,
      "platform": "Disney+"
    },
    {
      "title": "The Super Mario Bros. Movie",
      "poster":
          "https://image.tmdb.org/t/p/w500/qNBAXBIQlnOThrVVaH6pi3FFADM.jpg",
      "watchers": 380,
      "platform": "Peacock"
    },
  ];

  static final List<Map<String, dynamic>> _classics = [
    {
      "title": "The Godfather",
      "poster":
          "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsLleL3uqfDO9.jpg",
      "watchers": 890,
      "platform": "Prime"
    },
    {
      "title": "Schindler's List",
      "poster":
          "https://image.tmdb.org/t/p/w500/sF1U4EUQS8YHUYjNl3pMGNIQyr0.jpg",
      "watchers": 640,
      "platform": "Netflix"
    },
    {
      "title": "Forrest Gump",
      "poster":
          "https://image.tmdb.org/t/p/w500/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg",
      "watchers": 710,
      "platform": "Max"
    },
    {
      "title": "The Shawshank Redemption",
      "poster":
          "https://image.tmdb.org/t/p/w500/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
      "watchers": 930,
      "platform": "Netflix"
    },
  ];

  static final List<Map<String, dynamic>> _horror = [
    {
      "title": "Hereditary",
      "poster":
          "https://image.tmdb.org/t/p/w500/p9DKeXp6FxhHnLDYkQKf9rJSzaQ.jpg",
      "watchers": 470,
      "platform": "Max"
    },
    {
      "title": "Get Out",
      "poster":
          "https://image.tmdb.org/t/p/w500/tFXcEccSQMf3lfhfXKSU9iRBpa3.jpg",
      "watchers": 390,
      "platform": "Prime"
    },
    {
      "title": "A Quiet Place",
      "poster":
          "https://image.tmdb.org/t/p/w500/nAU74GmpUk7t5iklEp3bufwDq4n.jpg",
      "watchers": 355,
      "platform": "Netflix"
    },
    {
      "title": "The Conjuring",
      "poster":
          "https://image.tmdb.org/t/p/w500/wVYREutTvI2tmxr6ujrHT704wGF.jpg",
      "watchers": 510,
      "platform": "Max"
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          child: const TextField(
            decoration: InputDecoration(
              hintText: "Sen Ne İzliyorsun?",
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.redAccent),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildCategory("🔴 Şu An Çok İzlenenler", _trending),
            _buildCategory("🎬 Yeni Çıkanlar", _newReleases),
            _buildCategory("🌙 Gece Mood'u", _nightMood),
            _buildCategory("🏆 Tüm Zamanların Klasikleri", _classics),
            _buildCategory("😱 Korku & Gerilim", _horror),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), label: "Anasayfa"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Ara"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Hesap"),
        ],
      ),
    );
  }

  // Kategori bölümü: başlık + 200px yüksekliğinde yatay kaydırmalı şerit
  Widget _buildCategory(String title, List<Map<String, dynamic>> movies) {
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

  // Film kartı: sabit 135px genişlik, 200px yükseklik, afiş + gradient + bilgi
  Widget _buildMovieCard(Map<String, dynamic> movie) {
    return Container(
      width: 135,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Afiş görseli
            Image.network(
              movie['poster'],
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
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF1E1E1E),
                child: const Icon(Icons.broken_image,
                    color: Colors.grey, size: 40),
              ),
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
            // Platform rozeti (sol üst)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  movie['platform'],
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Film adı + izleyici sayısı (sol alt)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.bolt, size: 12, color: Colors.redAccent),
                      const SizedBox(width: 3),
                      Text(
                        "${movie['watchers']} izliyor",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
