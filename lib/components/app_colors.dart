import 'package:flutter/material.dart';

class AppColors {
  // Your current theme colors
  static const Color primaryOrange = Color(0xFFe0633c);
  static const Color darkOrange = Color(0xFF9c3719);
  static const Color darkGray = Color(0xFF333333);
  static const Color white = Colors.white;
  static const Color white70 = Colors.white70;

  // Button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryOrange, darkOrange],
  );
}