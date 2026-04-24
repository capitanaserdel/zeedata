import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF041F62); // Updated Zee Navy
  static const Color primarya = Color(0xFF011D5E); // Updated Zee Navy
  static const Color secondary = Color(0xFFFFCC00); // Zee Gold
  static const Color accent = Color(0xFF00BFFF); // Zee Light Blue
  
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF021035)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient zeeGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
