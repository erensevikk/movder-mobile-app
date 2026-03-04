import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  String? _identifierError;
  String? _passwordError;
  String? _generalError;

  late AnimationController _fadeController;

  bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@');
  }

  String _invalidCredentialsMessage(String identifier) {
    if (_looksLikeEmail(identifier)) {
      return 'E-posta veya şifre hatalı!';
    }
    return 'Kullanıcı adı veya şifre hatalı!';
  }

  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _identifierError = null;
      _passwordError = null;
      _generalError = null;
    });

    // Validasyon
    if (identifier.isEmpty) {
      setState(() => _identifierError = 'Kullanıcı adı veya e-posta zorunlu.');
      return;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Şifre zorunlu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": identifier,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = (data['token'] ?? '').toString();

        if (token.isNotEmpty) {
          await AuthService.saveToken(token);
        }

        if (!mounted) return;
        await _showLoginSuccessDialog(data['username'] ?? '');
      } else {
        final data = jsonDecode(response.body);
        final error = (data['error'] ?? 'Giriş başarısız.').toString();

        final isInvalidCredentials = response.statusCode == 401 ||
            error.toLowerCase().contains('şifre hatalı') ||
            error.toLowerCase().contains('kullanıcı adı/e-posta');

        final mappedError = isInvalidCredentials
            ? _invalidCredentialsMessage(identifier)
            : error;

        setState(() => _generalError = mappedError);
      }
    } catch (e) {
      setState(() =>
          _generalError = 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showLoginSuccessDialog(String username) async {
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
                'Hoş Geldin!',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            'Tekrar aramızda, $username. Movder seni özledi!',
            style: const TextStyle(color: Colors.white70, height: 1.4),
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arka plan blur efekti
          Image.network(
            'https://image.tmdb.org/t/p/w780/2ssWTSVklAEc98frZUQhgtGHx7s.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),

          // İçerik
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28.0, vertical: 48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Geri butonu
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Logo ve başlık
                    Container(
                      width: 60,
                      height: 60,
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
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.movie_filter_rounded,
                          color: Colors.white, size: 32),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Tekrar\nHoş Geldin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Film arkadaşların seni bekliyor.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Genel hata mesajı
                    if (_generalError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _generalError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Kullanıcı adı veya E-posta input
                    _buildInputField(
                      controller: _identifierController,
                      label: 'Kullanıcı Adı veya E-posta',
                      icon: Icons.person_outline_rounded,
                      errorText: _identifierError,
                      onChanged: (_) {
                        if (_identifierError != null) {
                          setState(() => _identifierError = null);
                        }
                        if (_generalError != null) {
                          setState(() => _generalError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 18),

                    // Şifre input
                    _buildInputField(
                      controller: _passwordController,
                      label: 'Şifre',
                      icon: Icons.lock_outline_rounded,
                      isObscure: _isPasswordObscured,
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isPasswordObscured = !_isPasswordObscured;
                          });
                        },
                        icon: Icon(
                          _isPasswordObscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white30,
                          size: 20,
                        ),
                      ),
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                        if (_generalError != null) {
                          setState(() => _generalError = null);
                        }
                      },
                      onSubmitted: (_) => _login(),
                    ),

                    const SizedBox(height: 32),

                    // Giriş Yap butonu
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          disabledBackgroundColor:
                              Colors.redAccent.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: Colors.redAccent.withValues(alpha: 0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Giriş Yap',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Bilgi notu
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14, color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(width: 6),
                            Text(
                              'Kullanıcı adı veya e-posta ile giriş yapabilirsin',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isObscure = false,
    String? errorText,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white30, size: 22),
              suffixIcon: suffixIcon,
              hintText: label,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
