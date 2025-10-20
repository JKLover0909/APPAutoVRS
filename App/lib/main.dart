import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'core/app_theme.dart';
import 'core/routes.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/vrs_provider.dart';
import 'providers/statistics_provider.dart';
import 'services/flutter_camera_service.dart';
import 'services/autovrs_websocket_service.dart';
import 'services/ai_detection_service.dart';
import 'services/local_database_service.dart';
import 'services/qcamber_gerber_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for Windows/macOS/Linux
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Hive - skip if fails on Windows
  try {
    if (Platform.isWindows) {
      // Use current directory for Windows to avoid path_provider issues
      final directory = Directory.current;
      await Hive.initFlutter('${directory.path}/hive_data');
    } else {
      await Hive.initFlutter();
    }
  } catch (e) {
    debugPrint(
      'Warning: Hive initialization failed, continuing without Hive: $e',
    );
    // Continue without Hive - app can still work
  }

  // Initialize database once at startup
  try {
    final dbService = LocalDatabaseService();
    final dbPath = await dbService.databasePath;
    debugPrint('SQLite database path: $dbPath');

    // Initialize database connection
    await dbService.database;
    debugPrint('Database initialized successfully');

    // Seed database with sample data
    // final seeder = DatabaseSeeder();
    // await seeder.seedDatabase();
  } catch (e) {
    debugPrint('Warning: Database initialization failed: $e');
    debugPrint('App will continue without local database');
  }

  runApp(const AutoVRSApp());
}

class AutoVRSApp extends StatefulWidget {
  const AutoVRSApp({super.key});

  @override
  State<AutoVRSApp> createState() => _AutoVRSAppState();
}

class _AutoVRSAppState extends State<AutoVRSApp> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VRSProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => FlutterCameraService()),
        ChangeNotifierProvider(
          create: (_) {
            final svc = AutoVRSWebSocketService();
            // Attempt to connect in background when the app starts
            svc.connect();
            return svc;
          },
        ),
        ChangeNotifierProvider(create: (_) => AIDetectionService()),
        ChangeNotifierProvider(create: (_) => QCamberGerberService()),
      ],
      child: Consumer<NavigationProvider>(
        builder: (context, navigationProvider, child) {
          return MaterialApp.router(
            title: 'AutoVRS - Hệ thống kiểm tra tự động',
            scaffoldMessengerKey: scaffoldMessengerKey,
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
