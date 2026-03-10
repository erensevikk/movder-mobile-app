import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/app_shell_screen.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../views/account_info_screen.dart';
import '../views/change_password_screen.dart';

class SettingsScreenViewModel extends BaseViewModel {
  void openAccountInfo() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildAccountInfo));
  }

  void openChangePassword() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildChangePassword));
  }

  void confirmDeleteAccount() {
    emitEffect(
      ShowDialogEffect(
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title:
              const Text('Hesabi Sil', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Hesabini ve tum verilerini kalici olarak silmek istedigine emin misin?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Iptal', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await deleteAccount();
              },
              child:
                  const Text('Sil', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteAccount() async {
    final result =
        await guard(() => AppScope.instance.settingsRepository.deleteAccount());
    if (result.isFailure) {
      emitEffect(ShowSnackbarEffect(message: result.failure!.message));
      return;
    }

    emitEffect(
        const NavigateToEffect(pageBuilder: _buildAppShell, clearStack: true));
    emitEffect(const ShowSnackbarEffect(message: 'Hesap silindi.'));
  }
}

Widget _buildAccountInfo(context) => const AccountInfoScreen();

Widget _buildChangePassword(context) => const ChangePasswordScreen();

Widget _buildAppShell(context) => const MainNavigatorScreen();
