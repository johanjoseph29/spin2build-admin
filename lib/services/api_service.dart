import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService extends ChangeNotifier {
  String? _token;
  static const Duration _timeout = Duration(seconds: 12);

  bool get isAuthenticated => _token != null;
  String? get token => _token;

  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  void clearSession() {
    _token = null;
    notifyListeners();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  String _cleanPath(String path) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final cleanP = path.startsWith('/') ? path : '/$path';
    return '$base$cleanP';
  }

  /// Tries endpoint with /api/admin or /admin prefix depending on backend route
  Future<http.Response> _executeWithFallback(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final candidates = <String>[path];

    // Support both /api/admin/... and /admin/... routes seamlessly
    if (path.startsWith('/api/admin/')) {
      candidates.add(path.replaceFirst('/api/admin/', '/admin/'));
    } else if (path.startsWith('/admin/')) {
      candidates.add(path.replaceFirst('/admin/', '/api/admin/'));
    }

    http.Response? lastResponse;
    dynamic lastException;

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse(_cleanPath(candidate));
        http.Response res;
        switch (method.toUpperCase()) {
          case 'POST':
            res = await http
                .post(uri,
                    headers: _headers,
                    body: body != null ? jsonEncode(body) : null)
                .timeout(_timeout);
            break;
          case 'PUT':
            res = await http
                .put(uri,
                    headers: _headers,
                    body: body != null ? jsonEncode(body) : null)
                .timeout(_timeout);
            break;
          case 'DELETE':
            res = await http.delete(uri, headers: _headers).timeout(_timeout);
            break;
          case 'GET':
          default:
            res = await http.get(uri, headers: _headers).timeout(_timeout);
            break;
        }

        // If not a 404, this endpoint candidate was matched!
        if (res.statusCode != 404) {
          return res;
        }
        lastResponse = res;
      } on TimeoutException {
        throw ApiException(
            'Connection timed out. Please check if Flask backend is running on ${ApiConfig.baseUrl}.');
      } on http.ClientException catch (e) {
        throw ApiException(
            'Unable to reach backend at ${ApiConfig.baseUrl}. (${e.message})');
      } catch (e) {
        lastException = e;
      }
    }

    if (lastResponse != null) {
      return lastResponse;
    }
    if (lastException != null) {
      if (lastException is ApiException) throw lastException;
      throw ApiException('Network error: $lastException');
    }
    throw ApiException('Server unavailable at ${ApiConfig.baseUrl}');
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      clearSession();
      throw ApiException('Session expired or unauthorized. Please log in again.',
          statusCode: 401);
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 400) {
      String msg = 'Request failed (${response.statusCode})';
      if (decoded is Map) {
        msg = decoded['description']?.toString() ??
            decoded['error']?.toString() ??
            decoded['message']?.toString() ??
            msg;
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }

    return decoded;
  }

  // --- Core HTTP Verbs ---
  Future<dynamic> get(String path) async {
    final res = await _executeWithFallback('GET', path);
    return _processResponse(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await _executeWithFallback('POST', path, body: body);
    return _processResponse(res);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final res = await _executeWithFallback('PUT', path, body: body);
    return _processResponse(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _executeWithFallback('DELETE', path);
    return _processResponse(res);
  }

  // --- Authentication ---
  Future<String> login(String username, String password) async {
    // The backend accepts {"password": "..."} or {"username": "...", "password": "..."}
    final res = await post('/admin/login', body: {
      'username': username,
      'password': password,
    });

    if (res is Map && res['token'] != null) {
      final token = res['token'].toString();
      setToken(token);
      return token;
    }
    throw ApiException('Invalid response from server during login');
  }

  Future<void> logout() async {
    try {
      await post('/admin/logout');
    } catch (_) {
      // Best-effort logout
    } finally {
      clearSession();
    }
  }

  // --- Dashboard Overview ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await get('/admin/overview');
    if (res is Map<String, dynamic>) {
      return res;
    }
    return <String, dynamic>{};
  }

  // --- Topic Management ---
  Future<List<dynamic>> getTopics({String? search}) async {
    String path = '/admin/topics';
    if (search != null && search.trim().isNotEmpty) {
      path += '?search=${Uri.encodeComponent(search.trim())}';
    }
    final res = await get(path);
    if (res is List) return res;
    return [];
  }

  Future<Map<String, dynamic>> addTopic(String title,
      {String? description}) async {
    final res = await post('/admin/topics', body: {
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> editTopic(int id,
      {required String title, String? description, bool force = false}) async {
    final res = await put('/admin/topics/$id', body: {
      'title': title.trim(),
      'description': description?.trim() ?? '',
      'force': force,
    });
    return res as Map<String, dynamic>;
  }

  Future<void> deleteTopic(int id, {bool confirm = true}) async {
    await delete('/admin/topics/$id?confirm=$confirm');
  }

  Future<Map<String, dynamic>> bulkAddTopics(String newlineSeparated) async {
    final res = await post('/admin/topics/bulk', body: {
      'topics': newlineSeparated,
    });
    return res as Map<String, dynamic>;
  }

  // --- Team Registration ---
  Future<List<dynamic>> getTeams() async {
    final res = await get('/admin/teams');
    if (res is List) return res;
    return [];
  }

  Future<Map<String, dynamic>> registerTeam(String name) async {
    final res = await post('/admin/teams', body: {
      'name': name.trim(),
    });
    return res as Map<String, dynamic>;
  }

  // --- Assignments ---
  Future<List<dynamic>> getAssignments() async {
    final res = await get('/admin/assignments');
    if (res is List) return res;
    return [];
  }

  Future<void> resetAssignments() async {
    await post('/admin/reset_assignments?confirm=true', body: {
      'confirmation': 'RESET ALL ASSIGNMENTS',
      'confirm': true,
    });
  }
}
