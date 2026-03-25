import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('${AppConstants.apiUrl}$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${AppConstants.apiUrl}$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${AppConstants.apiUrl}$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Something went wrong');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.apiUrl}$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }
}
