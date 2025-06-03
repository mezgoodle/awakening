// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart'; // Імпортуй наш провайдер
import 'screens/player_status_screen.dart'; // Імпортуй екран, який ми зараз створимо

void main() {
  runApp(
    MultiProvider(
      // Використовуємо MultiProvider, якщо в майбутньому буде більше провайдерів
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        // Тут можна буде додати інші провайдери, наприклад, QuestProvider
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Leveling App',
      theme: ThemeData(
          // Поки що базова тема, потім можна буде налаштувати
          primarySwatch: Colors.blue,
          brightness: Brightness.dark, // Для темної теми в стилі Solo Leveling
          // Можна одразу задати деякі кольори, близькі до Solo Leveling
          scaffoldBackgroundColor: const Color(0xFF121212), // Дуже темний фон
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            titleLarge: TextStyle(color: Colors.lightBlueAccent),
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Colors.lightBlueAccent,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F1F1F),
            foregroundColor: Colors.white,
          )),
      home: const PlayerStatusScreen(), // Встановлюємо наш екран як головний
    );
  }
}
