import '../../../../core/utils/url_resolver.dart';
import 'privacy_settings_model.dart';

class ProfileModel {
  const ProfileModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.city,
    required this.description,
    required this.avatarUrl,
    required this.coverUrl,
    required this.letterboxdImported,
    required this.privacySettings,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      userId: (map['userId'] ?? map['_id'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      avatarUrl:
          UrlResolver.resolveImageUrl(map['avatarUrl']?.toString()) ?? '',
      coverUrl: UrlResolver.resolveImageUrl(map['coverUrl']?.toString()) ?? '',
      letterboxdImported: map['letterboxdImported'] == true,
      privacySettings: PrivacySettingsModel.fromMap(
          map['privacySettings'] as Map<String, dynamic>?),
    );
  }

  final String userId;
  final String username;
  final String email;
  final String city;
  final String description;
  final String avatarUrl;
  final String coverUrl;
  final bool letterboxdImported;
  final PrivacySettingsModel privacySettings;
}
