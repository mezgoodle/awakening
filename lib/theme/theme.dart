import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Colors.blueAccent;
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightAppBarBackground = Color(0xFFE0E0E0);
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black87),
      titleLarge:
          TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
      headlineSmall:
          TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    radioTheme: RadioThemeData(
      fillColor:
          WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return Colors.grey[400]!;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryBlue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightAppBarBackground,
      foregroundColor: Colors.black,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            textStyle: const TextStyle(fontWeight: FontWeight.w600))),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightAppBarBackground,
      selectedItemColor: AppColors.primaryBlue,
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    primarySwatch: Colors.blue,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge:
          TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
      titleMedium:
          TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.w600),
      headlineSmall:
          TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    radioTheme: RadioThemeData(
      fillColor:
          WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.lightBlueAccent;
        }
        return Colors.grey[600]!;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Colors.lightBlueAccent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: Colors.lightBlueAccent,
            textStyle: const TextStyle(fontWeight: FontWeight.w600))),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1F1F1F),
      selectedItemColor: Colors.lightBlueAccent,
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );
}
