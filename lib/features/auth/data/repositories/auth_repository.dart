import '../../../../core/base/result.dart';
import '../../../../shared/models/app_user.dart';

abstract class AuthRepository {
  Future<Result<AppUser>> login({
    required String identifier,
    required String password,
  });

  Future<Result<AppUser>> register({
    required String username,
    required String email,
    required String password,
    required String city,
    required DateTime birthDate,
    required bool kvkkApproved,
    required bool termsApproved,
  });

  Future<void> logout();
}
