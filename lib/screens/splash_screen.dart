// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'home_screen.dart';
import 'initial_survey_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late PlayerProvider _playerProvider; // Зберігаємо екземпляр для відписки

  @override
  void initState() {
    super.initState();
    _playerProvider = context.read<PlayerProvider>(); // Отримуємо екземпляр
    _checkSurveyStatus();
  }

  Future<void> _checkSurveyStatus() async {
    if (!_playerProvider.isLoading) {
      // Якщо дані вже завантажені, навігацію можна викликати після побудови поточного кадру
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Перевіряємо mounted перед навігацією
          _navigate(_playerProvider.player.initialSurveyCompleted);
        }
      });
      return;
    }
    // Якщо дані ще завантажуються, додаємо слухача
    _playerProvider.addListener(_onPlayerProviderChange);
  }

  void _onPlayerProviderChange() {
    // Цей метод викликається, коли PlayerProvider викликає notifyListeners()
    if (!_playerProvider.isLoading && mounted) {
      // Важливо відписатися, щоб уникнути багаторазових викликів
      _playerProvider.removeListener(_onPlayerProviderChange);
      // Відкладаємо навігацію до завершення поточного кадру
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // І ще раз перевіряємо mounted
          _navigate(_playerProvider.player.initialSurveyCompleted);
        }
      });
    }
  }

  void _navigate(bool surveyCompleted) {
    // Перевірка mounted тут вже є з попередніх викликів, але для безпеки можна залишити
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) =>
            surveyCompleted ? const HomeScreen() : const InitialSurveyScreen(),
      ));
    }
  }

  @override
  void dispose() {
    // Відписуємося від слухача, щоб уникнути витоків пам'яті
    // та викликів setState на вже неіснуючому віджеті
    _playerProvider.removeListener(_onPlayerProviderChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Можна використовувати Consumer для автоматичного оновлення UI,
    // але для простоти і оскільки логіка навігації вже є,
    // залишимо простий Scaffold.
    // Якщо PlayerProvider.isLoading змінюється, _onPlayerProviderChange має спрацювати.
    return const Scaffold(
      backgroundColor: Color(0xFF121212), // Щоб фон був як у додатку
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
            ),
            SizedBox(height: 20),
            Text(
              'Завантаження даних гравця...',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
