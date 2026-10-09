import 'package:flutter/material.dart';

class AppConstants {
  // Replace with actual backend IP when running on emulator/device (e.g. 192.168.8.102 for physical device on same WiFi)
  static const String baseUrl = 'http://192.168.8.102:8080/api/v1';

  // Colors
  static const Color primaryGreen = Color(0xFF2E7D32); // Dark Green
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF757575);
}
