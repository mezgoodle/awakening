import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'providers/item_provider.dart';
import 'providers/player_provider.dart';
import 'providers/quest_provider.dart';
import 'providers/skill_provider.dart';
import 'providers/system_log_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/player_repository.dart';
import 'repositories/quest_repository.dart';
import 'screens/splash_screen.dart';
import 'services/app_logger_service.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final logger = AppLoggerService();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.writeLog(
      message: details.exceptionAsString(),
      severity: LogSeverity.error,
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.writeLog(
      message: error.toString(),
      severity: LogSeverity.error,
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  final catalogRepository = CatalogRepository();
  final playerRepository = PlayerRepository();
  final questRepository = QuestRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AppLoggerService>.value(value: logger),
        Provider<FirebaseAuth>.value(value: FirebaseAuth.instance),
        Provider<CatalogRepository>.value(value: catalogRepository),
        Provider<PlayerRepository>.value(value: playerRepository),
        Provider<QuestRepository>.value(value: questRepository),

        ChangeNotifierProvider(
          create: (_) =>
              SkillProvider(catalogRepository: catalogRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ItemProvider(catalogRepository: catalogRepository),
        ),
        ChangeNotifierProvider(create: (_) => SystemLogProvider()),

        ChangeNotifierProxyProvider3<FirebaseAuth, SkillProvider, ItemProvider,
            PlayerProvider>(
          create: (context) => PlayerProvider(
            null,
            null,
            null,
            null,
            playerRepository: playerRepository,
          ),
          update: (context, auth, skillProvider, itemProvider, prev) {
            prev!.update(auth, skillProvider, itemProvider);
            return prev;
          },
        ),

        ChangeNotifierProxyProvider2<PlayerProvider, ItemProvider, QuestProvider>(
          create: (context) => QuestProvider(
            questRepository: questRepository,
            playerRepository: playerRepository,
          ),
          update: (context, playerProvider, itemProvider, prev) {
            prev!.update(playerProvider, itemProvider);
            return prev;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Awakening - Solo Leveling',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
