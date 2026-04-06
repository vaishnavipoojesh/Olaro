import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFFFFD700); // Gold
  static const Color primaryDark = Color(0xFFE6C200);
  static const Color secondary = Color(0xFF00D4AA); // Teal

  // Background Colors
  static const Color background = Color(0xFF0A0E21);
  static const Color cardDark = Color(0xFF1D1F33);
  static const Color cardLight = Color(0xFF252A3D);

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8D8E98);
  static const Color textGold = Color(0xFFFFD700);

  // Status Colors
  static const Color success = Color(0xFF00D4AA);
  static const Color error = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFBE21);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1D1F33), Color(0xFF252A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient miningGradient = LinearGradient(
    colors: [Color(0xFF00D4AA), Color(0xFF00A388)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppStrings {
  static const String appName = 'CoinMine';
  static const String coinName = 'CM Coin';
  static const String coinSymbol = 'CM';
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const TextStyle coinBalance = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textGold,
  );
}
