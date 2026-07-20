import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/auth_storage_service.dart';
import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.background,
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
