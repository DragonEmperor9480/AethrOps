import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - Soft Periwinkle Palette
  static const Color primaryPurple = Color(
    0xFFB892FF,
  ); // Soft Periwinkle (Main Brand)
  static const Color purple50 = Color(0xFFF5F0FF); // Ultra light - backgrounds
  static const Color purple100 = Color(
    0xFFEBE0FF,
  ); // Very light - cards, highlights
  static const Color purple200 = Color(0xFFD4C4FF); // Light - hover states
  static const Color purple300 = Color(0xFFB892FF); // Main - primary actions
  static const Color purple400 = Color(
    0xFFA06EFF,
  ); // Medium - interactive elements
  static const Color purple500 = Color(0xFF8B4AFF); // Bold - emphasis
  static const Color purple600 = Color(0xFF7526FF); // Dark - headers, text
  static const Color purple700 = Color(0xFF6200EA); // Deep - strong emphasis
  static const Color purple800 = Color(0xFF4E00B8); // Very dark - contrast
  static const Color purple900 = Color(0xFF3A0086); // Ultra dark - shadows

  // Aliases for backward compatibility
  static const Color primaryBlue = Color(0xFF6EC6FF); // Soft blue complement
  static const Color accentCyan = Color(0xFF92FFB8); // Soft mint accent
  static const Color vpcColor = Color(0xFF92C6FF); // Soft blue for VPC

  // Complementary Colors
  static const Color accentBlue = Color(0xFF6EC6FF); // Soft blue complement
  static const Color accentPink = Color(0xFFFF92D0); // Soft pink accent
  static const Color accentMint = Color(0xFF92FFB8); // Soft mint accent
  static const Color accentCoral = Color(0xFFFFB892); // Soft coral accent

  // Service colors - Soft palette inspired
  static const Color iamColor = Color(0xFFFF6B6B); // Coral red
  static const Color s3Color = Color(0xFF6BDFAF); // Teal green
  static const Color cloudwatchColor = Color(0xFFB28BFF); // Soft purple
  static const Color ec2Color = Color(0xFFFFB36B); // Warm orange
  static const Color lambdaColor = Color(0xFFFFC792); // Soft amber
  static const Color rdsColor = Color(0xFF92C6FF); // Soft blue
  static const Color settingsColor = Color(0xFFA06EFF); // Medium purple

  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFFAF8FF); // Slight purple tint
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1B1B1F); // Title - darkest
  static const Color textSecondary = Color(0xFF2D2D33); // Subtitle
  static const Color textBody = Color(0xFF4A4A55); // Body text
  static const Color textMuted = Color(0xFF6F6F7A); // Muted/Caption
  static const Color borderColor = Color(0xFFEBE0FF); // Light purple border

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0F0F14); // Deep dark background
  static const Color cardBackgroundDark = Color(
    0xFF1A1A24,
  ); // Dark card background
  static const Color textPrimaryDark = Color(
    0xFFE8E6F0,
  ); // Light text for dark mode
  static const Color textSecondaryDark = Color(
    0xFFC4C2D0,
  ); // Secondary text for dark
  static const Color textBodyDark = Color(0xFFA8A6B0); // Body text for dark
  static const Color textMutedDark = Color(0xFF8C8A94); // Muted text for dark
  static const Color borderColorDark = Color(0xFF2D2D3A); // Dark border

  // Status colors - Soft versions
  static const Color successGreen = Color(0xFF22C55E); // Modern green
  static const Color errorRed = Color(0xFFFF6B6B); // Soft red
  static const Color warningAmber = Color(0xFFFFD392); // Soft amber
  static const Color infoBlue = Color(0xFF92C6FF); // Soft blue

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardTheme: const CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: borderColor),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.dark,
        background: backgroundDark,
        surface: cardBackgroundDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardTheme: CardThemeData(
        color: cardBackgroundDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: borderColorDark),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondaryDark),
      ),
    );
  }
}
