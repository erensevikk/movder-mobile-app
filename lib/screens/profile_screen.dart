import 'package:flutter/material.dart';

import '../features/profile/presentation/views/profile_screen.dart' as feature;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<feature.ProfileScreenState> _delegateKey =
      GlobalKey<feature.ProfileScreenState>();

  Future<void> refreshProfile() async {
    await _delegateKey.currentState?.refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return feature.ProfileScreen(key: _delegateKey);
  }
}
