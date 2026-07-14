import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.token,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  String? token;

  void setToken(String? newToken) {
    token = newToken;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['X-Flutter-Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client.get(
      _uri(path).replace(queryParameters: query),
      headers: _headers(),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(response.body);
      decoded = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage =
          decoded['message'] ?? decoded['exc'] ?? response.reasonPhrase;
      throw ApiException(
        serverMessage?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }

    return decoded['message'] is Map<String, dynamic>
        ? decoded['message'] as Map<String, dynamic>
        : decoded;
  }

  void dispose() {
    _client.close();
  }
}