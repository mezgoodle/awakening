import 'package:awakening/providers/player_provider.dart';
import 'package:awakening/providers/quest_provider.dart';
import 'package:awakening/providers/system_log_provider.dart';
import 'package:awakening/screens/splash_screen.dart';
import 'package:awakening/services/cloud_logger_service.dart';
import 'package:awakening/theme/theme.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

// Providers
import 'package:awakening/providers/theme_provider.dart';
import 'package:awakening/providers/skill_provider.dart';
import 'package:awakening/providers/item_provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      // --- 1. Basic services and providers without dependencies ---
      Provider<FirebaseAuth>(
        create: (_) => FirebaseAuth.instance,
      ),
      ChangeNotifierProvider(create: (_) => SkillProvider()),
      ChangeNotifierProvider(create: (_) => ItemProvider()),
      // --- 2. Services and providers with dependencies ---
      ChangeNotifierProxyProvider3<FirebaseAuth, SkillProvider, ItemProvider,
          PlayerProvider>(
        create: (context) => PlayerProvider(null, null, null, null),
        update: (context, auth, skillProvider, itemProvider,
            previousPlayerProvider) {
          previousPlayerProvider!
              .update(auth, skillProvider, itemProvider, null);
          return previousPlayerProvider;
        },
      ),

      ChangeNotifierProxyProvider2<PlayerProvider, ItemProvider, QuestProvider>(
        create: (context) => QuestProvider(),
        update: (context, playerProvider, itemProvider, previousQuestProvider) {
          previousQuestProvider!.update(playerProvider, itemProvider);
          return previousQuestProvider;
        },
      ),

      ChangeNotifierProxyProvider2<PlayerProvider, CloudLoggerService,
          SystemLogProvider>(
        create: (context) => SystemLogProvider(),
        update: (context, playerProvider, logger, previousLogProvider) {
          previousLogProvider!.update(playerProvider, logger);
          return previousLogProvider;
        },
      ),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Solo Leveling App',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
