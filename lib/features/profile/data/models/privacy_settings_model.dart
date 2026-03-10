class PrivacySettingsModel {
  const PrivacySettingsModel({
    required this.watchingVisibility,
    required this.profileVisibility,
    required this.searchDiscoverable,
  });

  factory PrivacySettingsModel.fromMap(Map<String, dynamic>? map) {
    return PrivacySettingsModel(
      watchingVisibility:
          (map?['watchingVisibility'] ?? 'friends_and_matches').toString(),
      profileVisibility: (map?['profileVisibility'] ?? 'public').toString(),
      searchDiscoverable: map?['searchDiscoverable'] != false,
    );
  }

  final String watchingVisibility;
  final String profileVisibility;
  final bool searchDiscoverable;
}
