import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Title styles
  static const TextStyle mainTitle = TextStyle(
    fontSize: 56,
    fontFamily: 'AlfaSlabOne',
    color: AppColors.white,
    letterSpacing: 8.0,
    shadows: [
      Shadow(
        offset: Offset(2, 2),
        blurRadius: 8,
        color: Colors.black87,
      ),
      Shadow(
        offset: Offset(1, 1),
        blurRadius: 4,
        color: Colors.black54,
      ),
    ],
  );

  static const TextStyle screenTitle = TextStyle(
    fontFamily: 'AlfaSlabOne',
    letterSpacing: 2.0,
    color: AppColors.white,
  );

  // Button text styles
  static const TextStyle buttonText = TextStyle(
    fontSize: 24,
    fontFamily: 'AlfaSlabOne',
    color: AppColors.white,
    letterSpacing: 2.0,
    shadows: [
      Shadow(
        offset: Offset(2, 2),
        blurRadius: 4,
        color: Colors.black45,
      ),
    ],
  );

  // Section headers
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 20,
    fontFamily: 'AlfaSlabOne',
    color: AppColors.white,
    letterSpacing: 2.0,
  );

  static const TextStyle sectionHeaderSmall = TextStyle(
    fontSize: 16,
    fontFamily: 'AlfaSlabOne',
    color: AppColors.white70,
    letterSpacing: 1.0,
  );

  // Display numbers/values
  static const TextStyle displayNumber = TextStyle(
    fontSize: 48,
    fontFamily: 'AlfaSlabOne',
    color: AppColors.primaryOrange,
  );

  static const TextStyle sessionId = TextStyle(
    fontSize: 32,
    fontFamily: 'AlfaSlabOne',
    color: AppColors.primaryOrange,
    letterSpacing: 4.0,
  );

  static const TextStyle playerCount = TextStyle(
    fontSize: 24,
    fontFamily: 'AlfaSlabOne',
    color: AppColors.primaryOrange,
  );

  // Body text
  static const TextStyle bodyText = TextStyle(
    fontSize: 18,
    color: AppColors.white70,
    height: 1.5,
  );

  static const TextStyle bodyTextWhite = TextStyle(
    fontSize: 16,
    color: AppColors.white,
  );

  // Counter button text
  static const TextStyle counterButton = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );
}