import 'package:flutter/material.dart';

import '../features/profile/presentation/views/user_detail_screen.dart' as feature;

class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({
    super.key,
    required this.userId,
    this.isMe = false,
    this.openImportOnStart = false,
  });

  final String userId;
  final bool isMe;
  final bool openImportOnStart;

  @override
  Widget build(BuildContext context) {
    return feature.UserDetailScreen(
      userId: userId,
      isMe: isMe,
      openImportOnStart: openImportOnStart,
    );
  }
}
