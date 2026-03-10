import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/auth_storage_service.dart';
import '../services/auth_service.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0F0F0F),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  await Future.wait(<Future<void>>[
    AuthStorageService.instance.init(),
    AuthService.init(),
  ]);
  runApp(const MovderApp());
}
