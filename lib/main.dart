import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/movie.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/global_chat_service.dart';
import 'screens/movie_detail_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/match_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
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
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
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

  final GlobalKey<MatchScreenState> _matchKey = GlobalKey<MatchScreenState>();
  Key _profileKey = UniqueKey();
  int _chatRefreshSignal = 0;

  List<Widget> get _pages => [
        const MovieRadarScreen(),
        MatchScreen(key: _matchKey),
        ChatListScreen(refreshSignal: _chatRefreshSignal),
        ProfileScreen(key: _profileKey),
      ];

  @override
  void initState() {
    super.initState();
    // Overlay bir sonraki frame'de hazır olur
    WidgetsBinding.instance.addPostFrameCallback((_) => _initServices());
  }

  Future<void> _initServices() async {
    if (!mounted) return;
    // Bildirim servisine global Overlay context'ini ver
    NotificationService.instance.init(context);
    // Aktif chat odaları backend'den gelene kadar boş başlatıyoruz.
    // chat_list_screen gerçek API'ye bağlanınca burayı doldururuz.
    await GlobalChatService.instance.init([]);
    GlobalChatService.instance.setChatListVisible(_currentIndex == 2);
  }

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
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            _matchKey.currentState?.setVisibility(true);
            _matchKey.currentState?.reloadWatchingStatus();
          } else {
            _matchKey.currentState?.setVisibility(false);
          }

          setState(() {
            if (index == 2 && _currentIndex != 2) {
              _chatRefreshSignal++;
            }
            _currentIndex = index;
            if (index == 3) {
              _profileKey = UniqueKey();
            }
          });

          // Sohbetler sekmesi görünürse in-app notification bastırılır.
          GlobalChatService.instance.setChatListVisible(index == 2);
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
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _selectedCity;
  final GlobalKey _cityFieldKey = GlobalKey();
  final ScrollController _kvkkScrollController = ScrollController();

  static const int _minimumAge = 16;

  static const List<String> _turkiyeIlleri = [
    'Adana',
    'Adıyaman',
    'Afyonkarahisar',
    'Ağrı',
    'Amasya',
    'Ankara',
    'Antalya',
    'Artvin',
    'Aydın',
    'Balıkesir',
    'Bilecik',
    'Bingöl',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Çanakkale',
    'Çankırı',
    'Çorum',
    'Denizli',
    'Diyarbakır',
    'Edirne',
    'Elazığ',
    'Erzincan',
    'Erzurum',
    'Eskişehir',
    'Gaziantep',
    'Giresun',
    'Gümüşhane',
    'Hakkâri',
    'Hatay',
    'Isparta',
    'Mersin',
    'İstanbul',
    'İzmir',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kırklareli',
    'Kırşehir',
    'Kocaeli',
    'Konya',
    'Kütahya',
    'Malatya',
    'Manisa',
    'Kahramanmaraş',
    'Mardin',
    'Muğla',
    'Muş',
    'Nevşehir',
    'Niğde',
    'Ordu',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Tekirdağ',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Şanlıurfa',
    'Uşak',
    'Van',
    'Yozgat',
    'Zonguldak',
    'Aksaray',
    'Bayburt',
    'Karaman',
    'Kırıkkale',
    'Batman',
    'Şırnak',
    'Bartın',
    'Ardahan',
    'Iğdır',
    'Yalova',
    'Karabük',
    'Kilis',
    'Osmaniye',
    'Düzce',
  ];

  bool _kvkkApproved = false;
  bool _termsApproved = false;
  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _cityError;
  String? _birthDateError;
  String? _kvkkError;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedBirthDate = now;
    _birthDateController.text =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year.toString().padLeft(4, '0')}';
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final city = _selectedCity;
    final birthDate = _selectedBirthDate;
    final currentYear = DateTime.now().year;

    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _cityError = null;
      _birthDateError = null;
      _kvkkError = null;
      _termsError = null;
    });

    debugPrint(
      'Register submit -> username:$username, email:$email, city:$city, birthDate:$birthDate, kvkk:$_kvkkApproved, terms:$_termsApproved',
    );

    String? usernameError;
    String? emailError;
    String? passwordError;
    String? confirmPasswordError;
    String? cityError;
    String? birthDateError;
    String? kvkkError;
    String? termsError;

    if (username.isEmpty) {
      usernameError = 'Kullanıcı adı zorunlu.';
    }

    if (email.isEmpty) {
      emailError = 'E-posta zorunlu.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailError = 'Geçerli bir e-posta adresi girin.';
    }

    if (password.isEmpty) {
      passwordError = 'Şifre zorunlu.';
    } else if (password.length < 6) {
      passwordError = 'Şifre en az 6 karakter olmalı.';
    } else if (!RegExp(r'[A-Z]').hasMatch(password)) {
      passwordError = 'Şifre en az 1 büyük harf içermeli.';
    }

    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Şifre tekrar zorunlu.';
    } else if (password.isNotEmpty && password != confirmPassword) {
      confirmPasswordError = 'Şifreler eşleşmiyor.';
    }

    if (city == null) {
      cityError = 'Şehir seçmelisin.';
    }

    if (birthDate == null) {
      birthDateError = 'Doğum tarihi seçmelisin.';
    } else {
      if (birthDate.year < 1900 || birthDate.year > currentYear) {
        birthDateError = 'Geçerli bir doğum tarihi seçin.';
      } else {
        int age = currentYear - birthDate.year;
        final hadBirthdayThisYear = (DateTime.now().month > birthDate.month) ||
            (DateTime.now().month == birthDate.month &&
                DateTime.now().day >= birthDate.day);
        if (!hadBirthdayThisYear) {
          age -= 1;
        }

        if (age < _minimumAge) {
          birthDateError = 'Kayıt için en az $_minimumAge yaşında olmalısın.';
        }
      }
    }

    if (!_kvkkApproved) {
      kvkkError = 'KVKK onayı zorunlu.';
    }

    if (!_termsApproved) {
      termsError = 'Kullanım şartları onayı zorunlu.';
    }

    if (usernameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmPasswordError != null ||
        cityError != null ||
        birthDateError != null ||
        kvkkError != null ||
        termsError != null) {
      setState(() {
        _usernameError = usernameError;
        _emailError = emailError;
        _passwordError = passwordError;
        _confirmPasswordError = confirmPasswordError;
        _cityError = cityError;
        _birthDateError = birthDateError;
        _kvkkError = kvkkError;
        _termsError = termsError;
      });
      return;
    }

    setState(() => _isLoading = true);
    final url = Uri.parse('http://10.0.2.2:8080/register');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
          "city": city,
          "birthYear": birthDate!.year,
          "birthDate":
              '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
          "kvkkApproved": _kvkkApproved,
          "termsApproved": _termsApproved,
        }),
      );

      debugPrint(
        'Register response -> status:${response.statusCode}, body:${response.body}',
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = (data['token'] ?? '').toString();

        if (token.isNotEmpty) {
          await AuthService.saveToken(token);
        }

        debugPrint(
          'Register success payload -> message:${data['message']}, userId:${data['userId']}, tokenSaved:${token.isNotEmpty}',
        );
        await _showRegistrationSuccessDialog();
      } else {
        final data = jsonDecode(response.body);
        final String errorMessage =
            (data['error'] ?? 'Bir hata oluştu').toString().toLowerCase();
        final String field = (data['field'] ?? '').toString().toLowerCase();
        final List<String> fields = (data['fields'] is List)
            ? (data['fields'] as List)
                .map((e) => e.toString().toLowerCase())
                .toList()
            : const [];

        final bool usernameTaken = fields.contains('username') ||
            field == 'username' ||
            errorMessage.contains('kullanıcı adı') ||
            errorMessage.contains('username') ||
            (errorMessage.contains('duplicate') &&
                errorMessage.contains('username'));

        final bool emailTaken = fields.contains('email') ||
            field == 'email' ||
            errorMessage.contains('e-posta') ||
            errorMessage.contains('email') ||
            (errorMessage.contains('duplicate') &&
                errorMessage.contains('email'));

        debugPrint(
          'Register parse -> field:$field, fields:$fields, usernameTaken:$usernameTaken, emailTaken:$emailTaken',
        );

        if (usernameTaken || emailTaken) {
          setState(() {
            if (usernameTaken) {
              _usernameError = 'Kullanıcı adı zaten alınmış.';
            }
            if (emailTaken) {
              _emailError = 'Bu e-posta adresi zaten kullanılıyor.';
            }
          });
          return;
        }

        final detail = (data['detail'] ?? '').toString();
        final baseError = (data['error'] ?? 'Bir hata oluştu').toString();
        final message = detail.isEmpty ? baseError : '$baseError\n$detail';
        _showSnackBar(message, Colors.red);
      }
    } catch (e) {
      debugPrint('Register exception -> $e');
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

  Future<void> _showRegistrationSuccessDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text(
                'Kayıt Başarılı',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'Başarıyla kayıt olundu. Movder\'ın eşsiz deneyimine hoş geldiniz.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Devam Et',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    debugPrint(
      'Post-register navigation -> MainNavigatorScreen. sessionState: token mevcut=${AuthService.isLoggedIn}',
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    _kvkkScrollController.dispose();
    super.dispose();
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
              const SizedBox(height: 40),
              _buildTextField(
                _usernameController,
                "Kullanıcı Adı",
                Icons.person_outline,
                errorText: _usernameError,
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailController,
                "E-posta",
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) {
                    setState(() => _emailError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _passwordController,
                "Şifre",
                Icons.lock_outline,
                isObscure: _isPasswordObscured,
                suffixIcon: _isPasswordObscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffixIconTap: () {
                  setState(() {
                    _isPasswordObscured = !_isPasswordObscured;
                  });
                },
                errorText: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _confirmPasswordController,
                "Şifre Tekrar",
                Icons.lock_reset_outlined,
                isObscure: _isConfirmPasswordObscured,
                suffixIcon: _isConfirmPasswordObscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffixIconTap: () {
                  setState(() {
                    _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                  });
                },
                errorText: _confirmPasswordError,
                onChanged: (_) {
                  if (_confirmPasswordError != null) {
                    setState(() => _confirmPasswordError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildCityDropdown(errorText: _cityError),
              const SizedBox(height: 16),
              _buildBirthDatePicker(errorText: _birthDateError),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _kvkkApproved,
                activeColor: Colors.redAccent,
                checkColor: Colors.white,
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _showKvkkModal,
                      child: const Text(
                        'KVKK',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(
                      ' metnini okudum ve onaylıyorum.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                controlAffinity: ListTileControlAffinity.leading,
                subtitle: _kvkkError == null
                    ? null
                    : Text(
                        _kvkkError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                onChanged: (value) {
                  setState(() {
                    _kvkkApproved = value ?? false;
                    if (_kvkkApproved) _kvkkError = null;
                  });
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _termsApproved,
                activeColor: Colors.redAccent,
                checkColor: Colors.white,
                title: const Text(
                  'Kullanım şartlarını kabul ediyorum.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                subtitle: _termsError == null
                    ? null
                    : Text(
                        _termsError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                onChanged: (value) {
                  setState(() {
                    _termsApproved = value ?? false;
                    if (_termsApproved) _termsError = null;
                  });
                },
              ),
              const SizedBox(height: 24),
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

  void _showKvkkModal() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1D1D1F), Color(0xFF111214)],
              ),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 14, color: Colors.redAccent),
                            SizedBox(width: 6),
                            Text(
                              'KVKK',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Aydınlatma Metni',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white30,
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Scrollbar(
                      controller: _kvkkScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      radius: const Radius.circular(12),
                      thickness: 6,
                      child: SingleChildScrollView(
                        controller: _kvkkScrollController,
                        padding: const EdgeInsets.only(right: 6),
                        child: const Text(
                          'Movder, kullanıcıların film ve dizi deneyimlerini paylaşabildiği, anlık eşleşme ve sohbet özellikleri sunan bir platformdur.\n\n'
                          'Bu kapsamda kayıt sırasında sağladığınız kullanıcı adı, e-posta adresi, şehir, doğum tarihi gibi kişisel veriler; hesap oluşturma, güvenli giriş, eşleşme deneyimini iyileştirme ve hizmet sürekliliği amaçlarıyla işlenir.\n\n'
                          'Şifre bilgileriniz açık metin olarak tutulmaz; güvenlik standartlarına uygun şekilde şifrelenerek saklanır.\n\n'
                          'Movder içerisinde film/dizi içerik görselleri ve meta verileri TMDB (The Movie Database) API üzerinden sağlanmaktadır. Bu kullanım yalnızca içerik keşfi ve profil deneyimini geliştirme amacı taşır. TMDB, Movder uygulamasını desteklememekte veya resmi olarak onaylamamaktadır.\n\n'
                          'Kişisel verileriniz; yasal yükümlülükler ve hizmetin teknik gereklilikleri dışında üçüncü taraflarla paylaşılmaz. KVKK kapsamındaki erişim, düzeltme, silme ve itiraz haklarınızı Movder destek kanalları üzerinden kullanabilirsiniz.\n\n'
                          'Bu metni onaylayarak, kişisel verilerinizin yukarıda belirtilen kapsamda işlenmesine açık rıza verdiğinizi beyan etmiş olursunuz.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectBirthDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateError = null;
        _birthDateController.text =
            '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year.toString().padLeft(4, '0')}';
      });
    }
  }

  Widget _buildBirthDatePicker({String? errorText}) {
    return TextField(
      controller: _birthDateController,
      readOnly: true,
      onTap: _selectBirthDate,
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.calendar_today_outlined, color: Colors.redAccent),
        hintText: 'Doğum Tarihi',
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.redAccent),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _showCityMenu() async {
    final fieldContext = _cityFieldKey.currentContext;
    if (fieldContext == null) return;

    final RenderBox fieldBox = fieldContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset fieldPosition =
        fieldBox.localToGlobal(Offset.zero, ancestor: overlay);

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(
        fieldPosition.dx,
        fieldPosition.dy + fieldBox.size.height + 2,
        fieldBox.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1E1E1E),
      constraints: BoxConstraints(
        minWidth: fieldBox.size.width,
        maxWidth: fieldBox.size.width,
        maxHeight: 192,
      ),
      items: _turkiyeIlleri
          .map(
            (city) => PopupMenuItem<String>(
              value: city,
              child: Text(
                city,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
    );

    if (selected != null) {
      setState(() {
        _selectedCity = selected;
      });
    }
  }

  Widget _buildCityDropdown({String? errorText}) {
    return InkWell(
      key: _cityFieldKey,
      borderRadius: BorderRadius.circular(15),
      onTap: () async {
        await _showCityMenu();
        if (_selectedCity != null && _cityError != null) {
          setState(() => _cityError = null);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.location_city_outlined, color: Colors.redAccent),
          suffixIcon:
              const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
          hintText: 'Şehir Seç',
          errorText: errorText,
          errorStyle: const TextStyle(color: Colors.redAccent),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          _selectedCity ?? 'Şehir Seç',
          style: TextStyle(
            color: _selectedCity == null ? Colors.white54 : Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isObscure = false,
      TextInputType? keyboardType,
      String? errorText,
      ValueChanged<String>? onChanged,
      IconData? suffixIcon,
      VoidCallback? onSuffixIconTap}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.redAccent),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: onSuffixIconTap,
                icon: Icon(suffixIcon, color: Colors.white70),
              ),
        hintText: hint,
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.redAccent),
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
                        Colors.black.withValues(alpha: 0.88),
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
                      color: Colors.black.withValues(alpha: 0.72),
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
                        color: Colors.black.withValues(alpha: 0.72),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            width: 1),
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
