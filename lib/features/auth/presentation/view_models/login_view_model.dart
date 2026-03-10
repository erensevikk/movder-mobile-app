import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/app_shell_screen.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/validators.dart';
import '../views/register_screen.dart';

class LoginViewModel extends BaseViewModel {
  ViewStatus status = ViewStatus.content;
  String? identifierError;
  String? passwordError;

  Future<void> submit({
    required String identifier,
    required String password,
  }) async {
    identifierError = null;
    passwordError = null;
    notifyListeners();

    final trimmedIdentifier = identifier.trim();
    identifierError = Validators.required(
      trimmedIdentifier,
      'Kullanıcı adı veya e-posta zorunlu.',
    );
    passwordError = Validators.required(password, 'Şifre zorunlu.');

    if (identifierError != null || passwordError != null) {
      notifyListeners();
      return;
    }

    final result = await guard(
      () => AppScope.instance.authRepository.login(
        identifier: trimmedIdentifier,
        password: password,
      ),
    );

    if (result.isFailure) {
      setError(result.failure!.message);
      return;
    }

    emitEffect(
      const ShowSnackbarEffect(message: 'Giriş başarılı.'),
    );
    emitEffect(
      const NavigateToEffect(
        pageBuilder: _buildAppShell,
        clearStack: true,
      ),
    );
  }

  void openRegister() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildRegister));
  }
}

Widget _buildAppShell(context) => const MainNavigatorScreen();

Widget _buildRegister(context) => const RegisterScreen();
