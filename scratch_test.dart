import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  // Assume backend is on localhost:8080
  final request = await client.putUrl(Uri.parse('http://localhost:8080/api/v1/patrol-assignments/444a145d-35e9-459f-82f3-d91af7349dd4'));
  request.headers.set('Content-Type', 'application/json');
  // Need a valid token though...
}
