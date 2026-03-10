import '../core/services/media_picker_service.dart';
import '../core/network/api_client.dart';
import '../core/services/auth_storage_service.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/data/services/auth_repository_impl.dart';
import '../features/home/data/repositories/movies_repository.dart';
import '../features/home/data/services/movies_repository_impl.dart';
import '../features/lists/data/repositories/lists_repository.dart';
import '../features/lists/data/services/lists_repository_impl.dart';
import '../features/notifications/data/repositories/notifications_repository.dart';
import '../features/notifications/data/services/notifications_repository_impl.dart';
import '../features/profile/data/repositories/import_repository.dart';
import '../features/profile/data/repositories/profile_repository.dart';
import '../features/profile/data/services/import_repository_impl.dart';
import '../features/profile/data/services/profile_repository_impl.dart';
import '../features/settings/data/repositories/settings_repository.dart';
import '../features/settings/data/services/settings_repository_impl.dart';

class AppScope {
  AppScope._({
    required this.authStorage,
    required this.apiClient,
    required this.authRepository,
    required this.moviesRepository,
    required this.profileRepository,
    required this.listsRepository,
    required this.importRepository,
    required this.settingsRepository,
    required this.notificationsRepository,
    required this.mediaPickerService,
  });

  factory AppScope.create() {
    final authStorage = AuthStorageService.instance;
    final apiClient = ApiClient(authStorage: authStorage);

    return AppScope._(
      authStorage: authStorage,
      apiClient: apiClient,
      authRepository: AuthRepositoryImpl(
        apiClient: apiClient,
        authStorage: authStorage,
      ),
      moviesRepository: MoviesRepositoryImpl(),
      profileRepository: ProfileRepositoryImpl(authStorage: authStorage),
      listsRepository: ListsRepositoryImpl(),
      importRepository: ImportRepositoryImpl(),
      settingsRepository: SettingsRepositoryImpl(
        apiClient: apiClient,
        authStorage: authStorage,
      ),
      notificationsRepository:
          NotificationsRepositoryImpl(apiClient: apiClient),
      mediaPickerService: MediaPickerService(),
    );
  }

  static final AppScope instance = AppScope.create();

  final AuthStorageService authStorage;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final MoviesRepository moviesRepository;
  final ProfileRepository profileRepository;
  final ListsRepository listsRepository;
  final ImportRepository importRepository;
  final SettingsRepository settingsRepository;
  final NotificationsRepository notificationsRepository;
  final MediaPickerService mediaPickerService;
}
