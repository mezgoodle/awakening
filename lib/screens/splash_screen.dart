import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import '../providers/player_provider.dart';
import '../services/app_logger_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppLoggerService _logger = AppLoggerService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        user = userCredential.user;
        _logger.writeLog(
          message: "Signed in anonymously with UID: ${user?.uid}",
          severity: LogSeverity.info,
          payload: {
            "id": user?.uid,
            "platform": defaultTargetPlatform.toString(),
          },
        );
      } else {
        _logger.writeLog(
          message: "User already signed in with UID: ${user.uid}",
          severity: LogSeverity.info,
          payload: {"id": user.uid},
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
        _showErrorAndStay();
      }
    } catch (e, stack) {
      _logger.writeLog(
        message: "AuthError: anonymous sign in failed: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
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
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _showErrorAndStay() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Authentication error. Please check your internet connection.",
        ),
      ),
    );
  }

  @override
  void dispose() {
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
              'Awakening the System...',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 1.2,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
