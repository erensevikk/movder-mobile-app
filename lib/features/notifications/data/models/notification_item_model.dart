class NotificationItemModel {
  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.avatarUrl,
  });

  factory NotificationItemModel.fromMap(Map<String, dynamic> map) {
    return NotificationItemModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      isRead: map['isRead'] == true,
      avatarUrl: (map['avatar'] ?? '').toString(),
    );
  }

  final String id;
  final String title;
  final String message;
  final String type;
  final String createdAt;
  final bool isRead;
  final String avatarUrl;
}
