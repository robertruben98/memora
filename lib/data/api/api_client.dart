import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);
  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiClient {
  final String baseUrl;
  final String token;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _http = client ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query,
    );
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await _http.get(_uri(path, query), headers: _headers);
    return _decode(res);
  }

  Future<dynamic> put(String path, Object body) async {
    final res = await _http.put(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> post(String path, Object body) async {
    final res = await _http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _http.delete(_uri(path), headers: _headers);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }
}

const _kBaseUrl = String.fromEnvironment(
  'MEMORA_API_BASE',
  defaultValue: 'https://memora-api.a-robertdev.com',
);
const _kToken = String.fromEnvironment(
  'MEMORA_API_TOKEN',
  defaultValue: 'memora-jiku-9834-api',
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: _kBaseUrl, token: _kToken);
});
