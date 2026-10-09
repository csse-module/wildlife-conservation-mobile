import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) => _run(() async {
    _user = null;
    await _api.clearToken();
    final data = await _api.postData('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    _user = User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await _api.saveToken(data['accessToken'] as String);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('user_profile', jsonEncode(_user!.toJson()));
  });

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String parkId,
  }) => _run(() async {
    await _api.postData('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'parkId': parkId,
    });
  });

  Future<bool> changePassword(String currentPassword, String newPassword) =>
      _run(() async {
        await _api.postData('/auth/change-password', {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        });
        await logout();
      });

  Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString('jwt_token') == null) return;
    try {
      final data = await _api.getData('/auth/me');
      _user = User.fromJson(Map<String, dynamic>.from(data as Map));
      await preferences.setString('user_profile', jsonEncode(_user!.toJson()));
    } on ApiException catch (error) {
      if (!error.canRetry) {
        await logout();
        return;
      }
      // Cached identity permits offline capture only; the backend validates every synchronized request.
      final cached = preferences.getString('user_profile');
      final token = preferences.getString('jwt_token');
      if (cached != null && token != null) {
        try {
          final payload =
              jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(token.split('.')[1]),
                      ),
                    ),
                  )
                  as Map<String, dynamic>;
          final profile = User.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
          if (payload['sub'] == profile.id &&
              (payload['exp'] as num).toInt() >
                  DateTime.now().millisecondsSinceEpoch ~/ 1000) {
            _user = profile;
          }
        } catch (_) {
          await logout();
          return;
        }
      }
    } catch (_) {
      await logout();
      return;
    }
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'The operation could not be completed. Please retry.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    await _api.clearToken();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('user_profile');
    notifyListeners();
  }
}
