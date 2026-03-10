import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/app_shell_screen.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/validators.dart';

class RegisterViewModel extends BaseViewModel {
  static const int minimumAge = 16;

  String? usernameError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  String? cityError;
  String? birthDateError;
  String? kvkkError;
  String? termsError;

  Future<void> submit({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    required String? city,
    required DateTime? birthDate,
    required bool kvkkApproved,
    required bool termsApproved,
  }) async {
    usernameError =
        Validators.required(username.trim(), 'Kullanıcı adı zorunlu.');
    emailError = Validators.email(email);
    passwordError = Validators.password(password);
    confirmPasswordError = confirmPassword.isEmpty
        ? 'Şifre tekrar zorunlu.'
        : (confirmPassword != password ? 'Şifreler eşleşmiyor.' : null);
    cityError = city == null ? 'Şehir seçmelisin.' : null;
    kvkkError = kvkkApproved ? null : 'KVKK onayı zorunlu.';
    termsError = termsApproved ? null : 'Kullanım şartları onayı zorunlu.';

    if (birthDate == null) {
      birthDateError = 'Doğum tarihi seçmelisin.';
    } else {
      final now = DateTime.now();
      var age = now.year - birthDate.year;
      final hadBirthday = (now.month > birthDate.month) ||
          (now.month == birthDate.month && now.day >= birthDate.day);
      if (!hadBirthday) {
        age -= 1;
      }
      birthDateError = age < minimumAge
          ? 'Kayıt için en az $minimumAge yaşında olmalısın.'
          : null;
    }

    notifyListeners();

    if (<Object?>[
      usernameError,
      emailError,
      passwordError,
      confirmPasswordError,
      cityError,
      birthDateError,
      kvkkError,
      termsError,
    ].any((item) => item != null)) {
      return;
    }

    final result = await guard(
      () => AppScope.instance.authRepository.register(
        username: username.trim(),
        email: email.trim(),
        password: password,
        city: city!,
        birthDate: birthDate!,
        kvkkApproved: kvkkApproved,
        termsApproved: termsApproved,
      ),
    );

    if (result.isFailure) {
      setError(result.failure!.message);
      return;
    }

    emitEffect(
      const ShowSnackbarEffect(message: 'Kayıt başarılı.'),
    );
    emitEffect(
      const NavigateToEffect(
        pageBuilder: _buildAppShell,
        clearStack: true,
      ),
    );
  }
}

Widget _buildAppShell(context) => const MainNavigatorScreen();
