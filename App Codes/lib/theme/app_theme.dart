import 'package:flutter/material.dart';

class AppTheme {
  // Brown/Chocolate Color Palette
  static const Color primaryBrown = Color(0xFF8B4513); // Saddle Brown
  static const Color chocolate = Color(0xFF7B3F00); // Dark Chocolate
  static const Color lightBrown = Color(0xFFD2691E); // Chocolate
  static const Color cream = Color(0xFFFFF8DC); // Cornsilk
  static const Color tan = Color(0xFFD2B48C); // Tan
  static const Color darkBrown = Color(0xFF654321); // Dark Brown
  static const Color beige = Color(0xFFF5F5DC); // Beige

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBrown,
        primary: primaryBrown,
        secondary: lightBrown,
        surface: cream,
        background: beige,
        error: Colors.red.shade700,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkBrown,
        onBackground: darkBrown,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: beige,
      appBarTheme: const AppBarTheme(
        backgroundColor: chocolate,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cream,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightBrown,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: chocolate,
        selectedItemColor: tan,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

