class NotificationSettingsModel {
  const NotificationSettingsModel({
    required this.pushEnabled,
    required this.matchAlerts,
    required this.messageAlerts,
    required this.friendAlerts,
    required this.inAppSounds,
    required this.vibration,
  });

  NotificationSettingsModel copyWith({
    bool? pushEnabled,
    bool? matchAlerts,
    bool? messageAlerts,
    bool? friendAlerts,
    bool? inAppSounds,
    bool? vibration,
  }) {
    return NotificationSettingsModel(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      matchAlerts: matchAlerts ?? this.matchAlerts,
      messageAlerts: messageAlerts ?? this.messageAlerts,
      friendAlerts: friendAlerts ?? this.friendAlerts,
      inAppSounds: inAppSounds ?? this.inAppSounds,
      vibration: vibration ?? this.vibration,
    );
  }

  final bool pushEnabled;
  final bool matchAlerts;
  final bool messageAlerts;
  final bool friendAlerts;
  final bool inAppSounds;
  final bool vibration;
}
