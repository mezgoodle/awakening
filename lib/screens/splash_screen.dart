// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Імпорт Firebase Auth

import '../providers/player_provider.dart';
import 'home_screen.dart';
import 'initial_survey_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Викликаємо асинхронну функцію ініціалізації
    _initialize();
  }

  Future<void> _initialize() async {
    // Відкладаємо виконання до завершення першого кадру, щоб контекст був повністю готовий
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      // 1. Автентифікація
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Якщо користувач не увійшов, виконуємо анонімний вхід
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        user = userCredential.user;
        print("Signed in anonymously with UID: ${user?.uid}");
      } else {
        print("User already signed in with UID: ${user.uid}");
      }

      if (user != null) {
        // 2. Ініціалізація PlayerProvider з UID
        // PlayerProvider тепер буде залежати від uid, тому ми не можемо просто
        // викликати його методи тут напряму, якщо він створюється в MultiProvider.
        // Замість цього, ми можемо оновити його стан, який він очікує.
        // В нашому новому підході з ChangeNotifierProxyProvider, PlayerProvider
        // буде автоматично оновлюватися, коли отримає uid.
        // Отже, тут нам потрібно лише дочекатися, поки PlayerProvider завантажить дані.

        final playerProvider = context.read<PlayerProvider>();

        // Додаємо слухача, щоб дочекатися завершення завантаження даних
        if (playerProvider.isLoading) {
          playerProvider.addListener(_onPlayerProviderLoaded);
        } else {
          // Якщо дані вже завантажені (дуже малоймовірно, але можливо)
          _navigate(playerProvider);
        }
      } else {
        // Обробка помилки входу
        _showErrorAndStay();
      }
    } catch (e) {
      print("Error during anonymous sign-in: $e");
      _showErrorAndStay();
    }
  }

  void _onPlayerProviderLoaded() {
    final playerProvider = context.read<PlayerProvider>();
    if (!playerProvider.isLoading && mounted) {
      // Важливо відписатися, щоб уникнути повторних викликів
      playerProvider.removeListener(_onPlayerProviderLoaded);
      _navigate(playerProvider);
    }
  }

  void _navigate(PlayerProvider playerProvider) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => playerProvider.player.initialSurveyCompleted
          ? const HomeScreen()
          : const InitialSurveyScreen(),
    ));
  }

  void _showErrorAndStay() {
    if (!mounted) return;
    // Показати помилку і залишитися на сплеш-скріні
    // (в реальному додатку тут може бути кнопка "Спробувати ще")
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text("Помилка автентифікації. Перевірте інтернет-з'єднання.")));
    // Можна додати віджет з повідомленням про помилку замість індикатора
  }

  @override
  void dispose() {
    // Переконуємося, що відписуємося
    if (context.mounted) {
      context.read<PlayerProvider>().removeListener(_onPlayerProviderLoaded);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
            ),
            SizedBox(height: 20),
            Text(
              'Автентифікація та завантаження...',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
