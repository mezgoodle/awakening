import 'package:awakening/services/cloud_logger_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import '../providers/player_provider.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final CloudLoggerService _logger = CloudLoggerService();

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
        _logger.writeLog(
          message: "Signed in anonymously with UID: ${user?.uid}",
          severity: CloudLogSeverity.info,
          payload: {
            "message": "User signed in anonymously",
            "context": {
              "id": user?.uid,
              "platform": defaultTargetPlatform.toString(),
            },
          },
        );
      } else {
        _logger.writeLog(
          message: "User already signed in with UID: ${user.uid}",
          severity: CloudLogSeverity.info,
          payload: {
            "message": "User already signed in",
            "context": {"id": user.uid},
          },
        );
      }

      if (user != null) {
        final playerProvider = context.read<PlayerProvider>();

        if (playerProvider.isLoading) {
          playerProvider.addListener(_onPlayerProviderLoaded);
        } else {
          _navigate();
        }
      } else {
        // Обробка помилки входу
        _showErrorAndStay();
      }
    } catch (e) {
      _logger.writeLog(
        message: "AuthError: anonymous_sign_in_failed",
        severity: CloudLogSeverity.error,
        payload: {"error": e.toString()},
      );
      _showErrorAndStay();
    }
  }

  void _onPlayerProviderLoaded() {
    final playerProvider = context.read<PlayerProvider>();
    if (!playerProvider.isLoading && mounted) {
      playerProvider.removeListener(_onPlayerProviderLoaded);
      _navigate();
    }
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()));
  }

  void _showErrorAndStay() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text("Помилка автентифікації. Перевірте інтернет-з'єднання.")));
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
