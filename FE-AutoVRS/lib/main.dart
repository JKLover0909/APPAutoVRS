import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

import 'core/app_theme.dart';
import 'core/routes.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/vrs_provider.dart';
import 'providers/statistics_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with fallback for Windows
  try {
    if (Platform.isWindows) {
      // Use a local directory for Windows to avoid path_provider issues
      final directory = Directory.current;
      await Hive.initFlutter('${directory.path}/hive_data');
    } else {
      await Hive.initFlutter();
    }
  } catch (e) {
    // Final fallback to default initialization
    print('Warning: Could not initialize Hive with custom path, using default: $e');
    try {
      await Hive.initFlutter();
    } catch (e2) {
      print('Error initializing Hive: $e2');
      // Continue without Hive if it fails completely
    }
  }

  runApp(const AutoVRSApp());
}

class AutoVRSApp extends StatelessWidget {
  const AutoVRSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VRSProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
      ],
      child: Consumer<NavigationProvider>(
        builder: (context, navigationProvider, child) {
          return MaterialApp.router(
            title: 'AutoVRS - Hệ thống kiểm tra tự động',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi', 'VN'), // Vietnamese
              Locale('en', 'US'), // English
            ],
            locale: const Locale('vi', 'VN'),
            routerConfig: AppRoutes.router,
          );
        },
      ),
    );
  }
}
