import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../core/utils/turkish_cities.dart';
import '../../../../core/utils/legal_texts.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../view_models/register_view_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with
        ViewModelBindingMixin<RegisterScreen, RegisterViewModel>,
        ViewEffectListenerMixin<RegisterScreen, RegisterViewModel> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _selectedCity;
  bool _kvkkApproved = false;
  bool _termsApproved = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  RegisterViewModel createViewModel() => RegisterViewModel();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedBirthDate = now;
    _birthDateController.text =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year.toString().padLeft(4, '0')}';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (selected == null) return;

    setState(() {
      _selectedBirthDate = selected;
      _birthDateController.text =
          '${selected.day.toString().padLeft(2, '0')}.${selected.month.toString().padLeft(2, '0')}.${selected.year.toString().padLeft(4, '0')}';
    });
  }

  Future<void> _pickCity() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: ListView(
          children: turkishCities
              .map(
                (city) => ListTile(
                  title:
                      Text(city, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.of(context).pop(city),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected == null) return;

    setState(() {
      _selectedCity = selected;
    });
  }

  void _showKVKKModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'KVKK',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim, secondAnim) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'KVKK Aydınlatma Metni',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white70, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StatefulBuilder(
                          builder: (context, _) {
                            final scrollController = ScrollController();
                            return Scrollbar(
                              controller: scrollController,
                              thumbVisibility: true,
                              interactive: true,
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: const Text(
                                  LegalTexts.kvkkText,
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Anladım',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTermsModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Terms',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim, secondAnim) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Kullanım Şartları',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white70, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StatefulBuilder(
                          builder: (context, _) {
                            final scrollController = ScrollController();
                            return Scrollbar(
                              controller: scrollController,
                              thumbVisibility: true,
                              interactive: true,
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: const Text(
                                  LegalTexts.termsText,
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Anladım',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildWithViewModel(BuildContext context, RegisterViewModel vm) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.movie_filter, color: Colors.redAccent, size: 60),
              const SizedBox(height: 20),
              const Text(
                "Movder'a\nHoş Geldin",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sinema tutkunlarıyla eşleşmeye hazır mısın?',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (vm.errorMessage != null) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AppTextField(
                controller: _usernameController,
                label: 'Kullanıcı Adı',
                icon: Icons.person_outline,
                errorText: vm.usernameError,
                onChanged: (_) => vm.usernameError = null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _emailController,
                label: 'E-posta',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                errorText: vm.emailError,
                onChanged: (_) => vm.emailError = null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordController,
                label: 'Şifre',
                icon: Icons.lock_outline,
                obscureText: _isPasswordObscured,
                errorText: vm.passwordError,
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
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Şifre Tekrar',
                icon: Icons.lock_reset_outlined,
                obscureText: _isConfirmPasswordObscured,
                errorText: vm.confirmPasswordError,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                    });
                  },
                  icon: Icon(
                    _isConfirmPasswordObscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: TextEditingController(text: _selectedCity ?? ''),
                label: _selectedCity ?? 'Şehir Seç',
                icon: Icons.location_city_outlined,
                errorText: vm.cityError,
                readOnly: true,
                onTap: _pickCity,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _birthDateController,
                label: 'Doğum Tarihi',
                icon: Icons.calendar_today_outlined,
                errorText: vm.birthDateError,
                readOnly: true,
                onTap: _pickBirthDate,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _kvkkApproved,
                activeColor: Colors.redAccent,
                title: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'KVKK',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = _showKVKKModal,
                      ),
                      const TextSpan(text: ' metnini okudum ve onaylıyorum.'),
                    ],
                  ),
                ),
                subtitle: vm.kvkkError == null
                    ? null
                    : Text(
                        vm.kvkkError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                onChanged: (value) {
                  setState(() {
                    _kvkkApproved = value ?? false;
                    vm.kvkkError = null;
                  });
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _termsApproved,
                activeColor: Colors.redAccent,
                title: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Kullanım şartlarını',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = _showTermsModal,
                      ),
                      const TextSpan(text: ' kabul ediyorum.'),
                    ],
                  ),
                ),
                subtitle: vm.termsError == null
                    ? null
                    : Text(
                        vm.termsError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                onChanged: (value) {
                  setState(() {
                    _termsApproved = value ?? false;
                    vm.termsError = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Kayıt Ol',
                isLoading: vm.isLoading,
                onPressed: () => vm.submit(
                  username: _usernameController.text,
                  email: _emailController.text,
                  password: _passwordController.text,
                  confirmPassword: _confirmPasswordController.text,
                  city: _selectedCity,
                  birthDate: _selectedBirthDate,
                  kvkkApproved: _kvkkApproved,
                  termsApproved: _termsApproved,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
