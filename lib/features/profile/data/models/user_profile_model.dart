import '../../../../core/utils/url_resolver.dart';

class WatchHistoryItemModel {
  const WatchHistoryItemModel({
    required this.posterPath,
  });

  factory WatchHistoryItemModel.fromMap(Map<String, dynamic> map) {
    return WatchHistoryItemModel(
      posterPath:
          UrlResolver.resolveImageUrl(map['posterPath']?.toString()) ?? '',
    );
  }

  final String posterPath;
}

class UserProfileModel {
  const UserProfileModel({
    required this.userId,
    required this.username,
    required this.city,
    required this.description,
    required this.avatarUrl,
    required this.coverUrl,
    required this.letterboxdImported,
    required this.canSeeProfileDetails,
    required this.watchHistory,
  });

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    final history = (map['watchHistory'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((item) => WatchHistoryItemModel.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList();

    return UserProfileModel(
      userId: (map['userId'] ?? map['_id'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      avatarUrl:
          UrlResolver.resolveImageUrl(map['avatarUrl']?.toString()) ?? '',
      coverUrl: UrlResolver.resolveImageUrl(map['coverUrl']?.toString()) ?? '',
      letterboxdImported: map['letterboxdImported'] == true,
      canSeeProfileDetails: map['canSeeProfileDetails'] != false,
      watchHistory: history,
    );
  }

  final String userId;
  final String username;
  final String city;
  final String description;
  final String avatarUrl;
  final String coverUrl;
  final bool letterboxdImported;
  final bool canSeeProfileDetails;
  final List<WatchHistoryItemModel> watchHistory;
}
