import '../models/movie_list_model.dart';
import '../models/profile_model.dart';
import '../models/user_profile_model.dart';
import '../models/watch_status_model.dart';
import '../models/match_history_model.dart';
abstract class ProfileRepository {
  Future<ProfileModel?> getMyProfile();

  Future<UserProfileModel?> getMyDetailProfile();

  Future<UserProfileModel?> getUserDetailProfile(String userId);

  Future<WatchStatusModel?> getMyWatchStatus();

  Future<List<MovieListModel>> getMyLists();

  Future<UserProfileModel?> updateMyProfile({
    String? description,
    List<int>? imageBytes,
    String? imageFileName,
    List<int>? coverImageBytes,
    String? coverImageFileName,
    bool deleteCover,
  });

  Future<void> logout();

  Future<MatchHistoryResponse?> getMatchHistory({int page = 1, int limit = 20});
}
