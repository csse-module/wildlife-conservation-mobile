import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _user != null;

  // Login Method
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Backend returns StandardResponse<LoginResponseDTO>
        // Check if data has the structure we expect based on standard response
        // e.g. { "status": 200, "message": "Success", "data": { "accessToken": "...", "user": {...} } }
        
        // Handling the standard response wrapper (assuming typical structure)
        final responseData = data['data'] ?? data;
        
        final String token = responseData['accessToken'];
        final userData = responseData['user'];

        await _apiService.saveToken(token);
        _user = User.fromJson(userData);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Handle error responses
        final data = jsonDecode(response.body);
        _errorMessage = data['message'] ?? 'Login failed. Please check your credentials.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred. Please try again later.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  // Register Method
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String parkId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/register', {
        'name': name,
        'email': email,
        'password': password,
        'parkId': parkId,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Success! Note: The API does NOT return a token on registration,
        // so the user must log in manually after this succeeds.
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Handle error
        final data = jsonDecode(response.body);
        if (data['error'] != null && data['error']['errorDescription'] != null) {
          _errorMessage = data['error']['errorDescription'];
          
          // Append field errors if available
          if (data['error']['fieldErrors'] != null) {
            final Map<String, dynamic> fieldErrors = data['error']['fieldErrors'];
            if (fieldErrors.isNotEmpty) {
               _errorMessage = '$_errorMessage (${fieldErrors.values.first})';
            }
          }
        } else {
          _errorMessage = data['description'] ?? 'Registration failed.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred during registration. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  // Change Password Method
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      if (response.statusCode == 200) {
        // Success! API returns {"passwordChangeRequired":false,"reloginRequired":true}
        // As per spec, we must clear the token and require login again.
        await logout();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data['description'] ?? 'Failed to change password.';
        if (data['error'] != null && data['error']['errorDescription'] != null) {
          _errorMessage = data['error']['errorDescription'];
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred. Please try again later.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout Method
  Future<void> logout() async {
    await _apiService.clearToken();
    _user = null;
    notifyListeners();
  }
}
