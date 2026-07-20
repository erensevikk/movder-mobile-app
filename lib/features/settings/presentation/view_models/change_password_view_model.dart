import '../../../../app/app_scope.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/validators.dart';

class ChangePasswordViewModel extends BaseViewModel {
  String oldPassword = '';
  String newPassword = '';
  String confirmPassword = '';

  String? oldPasswordError;
  String? newPasswordError;
  String? confirmPasswordError;

  void updateOldPassword(String value) {
    oldPassword = value;
    oldPasswordError = null;
    notifyListeners();
  }

  void updateNewPassword(String value) {
    newPassword = value;
    newPasswordError = null;
    confirmPasswordError = null;
    notifyListeners();
  }

  void updateConfirmPassword(String value) {
    confirmPassword = value;
    confirmPasswordError = null;
    notifyListeners();
  }

  Future<void> save() async {
    oldPasswordError =
        Validators.required(oldPassword, 'Mevcut sifre zorunlu.');
    newPasswordError = _validateNewPassword(newPassword);
    confirmPasswordError = _validateConfirmPassword(confirmPassword);
    notifyListeners();

    if (oldPasswordError != null ||
        newPasswordError != null ||
        confirmPasswordError != null) {
      return;
    }

    final result = await guard(
      () => AppScope.instance.settingsRepository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      ),
    );

    if (result.isFailure) {
      emitEffect(ShowSnackbarEffect(message: result.failure!.message));
      return;
    }

    emitEffect(const ShowSnackbarEffect(message: 'Şifre güncellendi.'));
    emitEffect(const PopEffect(true));
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Sifre zorunlu.';
    }
    if (password.length < 6) {
      return 'Sifre en az 6 karakter olmali.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'En az 1 buyuk harf icermeli.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Sifre tekrar zorunlu.';
    }
    if (newPassword != value) {
      return 'Sifreler eslesmiyor.';
    }
    return null;
  }
}
