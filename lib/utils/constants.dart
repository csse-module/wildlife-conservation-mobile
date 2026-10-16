import 'package:flutter/material.dart';

class AppConstants {
  // Override API_BASE_URL for a different device or network.
  // Deployed and Local URLs for flexible testing in both environments:
  static const String deployedBaseUrl = 'http://192.168.8.102:8080/api/v1'; // Configured deployed / LAN URL
  static const String currentLanBaseUrl = 'http://192.168.8.100:8080/api/v1'; // Current local PC Wi-Fi IP
  static const String usbDebugBaseUrl = 'http://127.0.0.1:8080/api/v1'; // Physical device USB debugging (adb reverse)
  static const String localhostBaseUrl = 'http://localhost:8080/api/v1'; // Web and desktop testing
  static const String localBaseUrl = 'http://10.0.2.2:8080/api/v1'; // Android emulator testing

  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8080/api/v1');

  // Colors
  static const Color primaryGreen = Color(0xFF2E7D32); // Dark Green
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF757575);
}
