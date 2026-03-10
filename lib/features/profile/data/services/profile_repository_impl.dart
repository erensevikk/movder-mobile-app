import 'dart:typed_data';

import '../../../../core/services/auth_storage_service.dart';
import '../../../../services/api_service.dart';
import '../models/movie_list_model.dart';
import '../models/profile_model.dart';
import '../models/user_profile_model.dart';
import '../models/watch_status_model.dart';
import '../repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required AuthStorageService authStorage,
  }) : _authStorage = authStorage;

  final AuthStorageService _authStorage;

  @override
  Future<List<MovieListModel>> getMyLists() async {
    final lists = await ApiService.getMyLists();
    final enrichedLists = <MovieListModel>[];

    for (final list in lists) {
      final id = (list['id'] ?? list['_id'] ?? '').toString();
      final items = id.isEmpty
          ? const <Map<String, dynamic>>[]
          : await ApiService.getListItems(id);
      enrichedLists.add(
        MovieListModel.fromMap(
          <String, dynamic>{
            ...list,
            'items': items,
          },
        ),
      );
    }

    return enrichedLists;
  }

  @override
  Future<ProfileModel?> getMyProfile() async {
    final profile = await ApiService.getProfile();
    if (profile == null) return null;
    return ProfileModel.fromMap(profile);
  }

  @override
  Future<UserProfileModel?> getMyDetailProfile() async {
    final profile = await ApiService.getProfile();
    if (profile == null) return null;
    return UserProfileModel.fromMap(profile);
  }

  @override
  Future<WatchStatusModel?> getMyWatchStatus() async {
    final status = await ApiService.getMyWatchStatus();
    if (status == null || status['watching'] != true) {
      return null;
    }
    return WatchStatusModel.fromMap(status);
  }

  @override
  Future<void> logout() async {
    await _authStorage.clearToken();
  }

  @override
  Future<UserProfileModel?> getUserDetailProfile(String userId) async {
    final profile = await ApiService.getUserProfile(userId);
    if (profile == null) return null;
    return UserProfileModel.fromMap(profile);
  }

  @override
  Future<UserProfileModel?> updateMyProfile({
    String? description,
    List<int>? imageBytes,
    String? imageFileName,
    List<int>? coverImageBytes,
    String? coverImageFileName,
    bool deleteCover = false,
  }) async {
    final result = await ApiService.updateProfile(
      description: description,
      imageBytes: imageBytes == null ? null : Uint8List.fromList(imageBytes),
      imageFileName: imageFileName,
      coverImageBytes:
          coverImageBytes == null ? null : Uint8List.fromList(coverImageBytes),
      coverImageFileName: coverImageFileName,
      deleteCover: deleteCover,
    );
    if (result == null || result['error'] != null) return null;

    final latest = await ApiService.getProfile();
    if (latest == null) return null;
    return UserProfileModel.fromMap(latest);
  }
}
