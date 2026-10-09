import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';
import 'api_exception.dart';

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConstants.baseUrl;

  final http.Client _client;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 25);

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
      'X-Request-ID': const Uuid().v4(),
      if (token != null &&
          endpoint != '/auth/login' &&
          endpoint != '/auth/register')
        'Authorization': 'Bearer $token',
    };

    final response = await _client
        .post(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return response;
  }

  // Generic PUT Request
  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      'X-Request-ID': const Uuid().v4(),
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await _client
        .put(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return response;
  }

  // Generic GET Request
  Future<http.Response> get(String endpoint) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      'X-Request-ID': const Uuid().v4(),
      if (token != null && endpoint != '/auth/registration-parks')
        'Authorization': 'Bearer $token',
    };

    final response = await _client
        .get(Uri.parse('$_baseUrl$endpoint'), headers: headers)
        .timeout(_timeout);

    return response;
  }

  // Multipart PUT Request for File Uploads
  Future<http.StreamedResponse> uploadFile(
    String endpoint,
    String filePath,
  ) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl$endpoint'),
    );

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    return await _client.send(request).timeout(_timeout);
  }

  Future<dynamic> getData(String endpoint, [Map<String, String>? query]) =>
      _json(() => get(_endpoint(endpoint, query)));

  Future<dynamic> putData(String endpoint, Map<String, dynamic> body) =>
      _json(() => put(endpoint, body));

  Future<dynamic> postData(
    String endpoint, [
    Map<String, dynamic> body = const {},
  ]) => _json(() => post(endpoint, body));

  Future<Uint8List> getBytes(String endpoint) async {
    try {
      final response = await get(endpoint);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw responseError(response);
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please retry.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the server. Check your connection.',
      );
    }
  }

  Future<void> uploadImage({
    required String id,
    required String parkId,
    required String category,
    required Uint8List bytes,
    required String name,
  }) async {
    try {
      final token = await _getToken();
      final request =
          http.MultipartRequest('PUT', Uri.parse('$_baseUrl/media/$id'))
            ..fields.addAll({'parkId': parkId, 'category': category})
            ..headers['X-Request-ID'] = const Uuid().v4()
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: name,
                contentType: _imageContentType(bytes),
              ),
            );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      ).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw responseError(response);
      }
    } on TimeoutException {
      throw const ApiException('Image upload timed out. Please retry.');
    } on http.ClientException {
      throw const ApiException('Cannot upload the image while offline.');
    }
  }

  MediaType _imageContentType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return MediaType('image', 'jpeg');
    }
    throw const ApiException('Choose a JPEG or PNG photo.', statusCode: 415);
  }

  Future<dynamic> _json(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw responseError(response);
      }
      final envelope =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (envelope['status'] != '00') throw responseError(response);
      return envelope['data'];
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please retry.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the server. Check your connection.',
      );
    } on FormatException {
      throw const ApiException('The server returned an unreadable response.');
    }
  }

  static ApiException responseError(http.Response response) {
    try {
      final envelope =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final error = envelope['error'] as Map<String, dynamic>? ?? {};
      final fields = error['fieldErrors'] as Map<String, dynamic>? ?? {};
      final description =
          error['errorDescription'] as String? ??
          'The request could not be completed.';
      return ApiException(
        fields.isEmpty ? description : '$description ${fields.values.first}',
        statusCode: response.statusCode,
        code: error['errorCode'] as String?,
      );
    } catch (_) {
      return ApiException(
        'The request failed (${response.statusCode}). Please retry.',
        statusCode: response.statusCode,
      );
    }
  }

  String _endpoint(String endpoint, Map<String, String>? query) {
    if (query == null || query.isEmpty) return endpoint;
    final uri = Uri.parse(endpoint);
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...query})
        .toString();
  }
}
