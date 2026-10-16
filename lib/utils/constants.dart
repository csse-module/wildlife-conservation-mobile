import 'package:flutter/material.dart';

class AppConstants {
  // Override API_BASE_URL when targeting a different backend.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue:
          'https://wildlife-conservation-backend-5nkw.onrender.com/api/v1');

  // Colors
  static const Color primaryGreen = Color(0xFF2E7D32); // Dark Green
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF757575);
}
