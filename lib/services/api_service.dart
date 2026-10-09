import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  // Method to get JWT Token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Method to set JWT Token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  // Clear Token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // Generic POST Request
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );

    return response;
  }

  // Generic PUT Request
  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );

    return response;
  }

  // Generic GET Request
  Future<http.Response> get(String endpoint) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: headers,
    );

    return response;
  }

  // Multipart PUT Request for File Uploads
  Future<http.StreamedResponse> uploadFile(String endpoint, String filePath) async {
    final token = await _getToken();
    final request = http.MultipartRequest('PUT', Uri.parse('${AppConstants.baseUrl}$endpoint'));
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    
    return await request.send();
  }
}
