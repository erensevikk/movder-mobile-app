import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/account_info_model.dart';

class AccountInfoViewModel extends BaseViewModel {
  ViewStatus status = ViewStatus.initial;
  String username = '';
  String email = '';
  String? city;

  String? usernameError;
  String? emailError;
  String? cityError;

  @override
  Future<void> initialize() async {
    status = ViewStatus.loading;
    notifyListeners();

    final result = await AppScope.instance.settingsRepository.getAccountInfo();
    if (result.isFailure) {
      status = ViewStatus.error;
      setError(result.failure!.message);
      return;
    }

    final model = result.data!;
    username = model.username;
    email = model.email;
    city = model.city.isEmpty ? null : model.city;
    status = ViewStatus.content;
    notifyListeners();
  }

  void updateUsername(String value) {
    username = value;
    usernameError = null;
    notifyListeners();
  }

  void updateEmail(String value) {
    email = value;
    emailError = null;
    notifyListeners();
  }

  void updateCity(String? value) {
    city = value;
    cityError = null;
    notifyListeners();
  }

  Future<void> save() async {
    usernameError = Validators.minLength(
      username.trim(),
      min: 3,
      message: 'En az 3 karakter girin.',
    );
    emailError = Validators.email(email.trim());
    cityError = city == null || city!.trim().isEmpty ? 'Sehir secin.' : null;
    notifyListeners();

    if (usernameError != null || emailError != null || cityError != null) {
      return;
    }

    final result = await guard(
      () => AppScope.instance.settingsRepository.updateAccountInfo(
        AccountInfoModel(
          username: username.trim(),
          email: email.trim(),
          city: city!.trim(),
        ),
      ),
    );

    if (result.isFailure) {
      emitEffect(ShowSnackbarEffect(message: result.failure!.message));
      return;
    }

    emitEffect(const ShowSnackbarEffect(message: 'Bilgiler guncellendi.'));
    emitEffect(const PopEffect(true));
  }
}
