// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/quest_provider.dart'; // Імпортуємо QuestProvider
// import 'screens/player_status_screen.dart'; // Будемо використовувати новий HomeScreen
import 'screens/home_screen.dart'; // Новий головний екран з навігацією
import 'screens/initial_survey_screen.dart'; // Імпортуємо екран опитування
import 'screens/splash_screen.dart'; // Створимо простий сплеш-скрін

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final playerProvider = PlayerProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: playerProvider),
        ChangeNotifierProvider(create: (_) => QuestProvider()),
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
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            titleLarge: TextStyle(
                color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
            titleMedium:
                TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.w600),
            headlineSmall: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold), // для заголовків
          ),
          radioTheme: RadioThemeData(
            // Стилізація радіокнопок
            fillColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.lightBlueAccent;
              }
              return Colors.grey[600]!;
            }),
            // visualDensity: VisualDensity.compact, // Можна зробити компактнішими
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Colors.lightBlueAccent,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F1F1F),
            foregroundColor: Colors.white,
          ),
          cardTheme: CardTheme(
            // Стилізація карток
            color: const Color(
                0xFF1E1E1E), // Трохи темніший ніж 2A2A2A для різноманітності
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            // Глобальний стиль для ElevatedButton
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                  foregroundColor: Colors.lightBlueAccent,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600))),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            // Стилізація BottomNavigationBar
            backgroundColor: const Color(0xFF1F1F1F),
            selectedItemColor: Colors.lightBlueAccent,
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          )),
      home: const SplashScreen(),
    );
  }
}
