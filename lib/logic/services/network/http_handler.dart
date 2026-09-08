import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:yack/logic/services/crashlytics_service.dart';

/// Typed API error carrying the HTTP status and the backend error `code`
/// (e.g. `EMAIL_NOT_VERIFIED`, `ACCOUNT_INCOMPLETE`, `CONTRACT_EXPIRED`).
/// The backend error `code` was previously discarded (F-49).
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    this.statusCode = 0,
    this.code = '',
    required this.message,
  });

  @override
  String toString() => message;
}

class HttpHandler {
  static final HttpHandler _instance = HttpHandler._internal();
  factory HttpHandler() => _instance;

  HttpHandler._internal();

  static const Duration _requestTimeout = Duration(seconds: 20);

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Uses the local backend automatically for development. Production builds
  /// must provide an explicit HTTPS endpoint with `--dart-define=API_BASE_URL=...`.
  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }

    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL is required for release builds. '
        'Build with --dart-define=API_BASE_URL=https://your-backend.example',
      );
    }

    if (kIsWeb) return 'http://127.0.0.1:3000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://127.0.0.1:3000';
  }

  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception(
        'Unable to authenticate this request. Please sign in again.',
      );
    }
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getIdToken();
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final requestBody = <String, dynamic>{...?body};

    final response = await _performRequest(
      () async => http.post(
        url,
        headers: await _headers(),
        body: jsonEncode(requestBody),
      ),
      url,
    );

    return _handleResponse(response);
  }

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final response = await _performRequest(
      () async => http.get(url, headers: await _headers()),
      url,
    );
    return _handleResponse(response);
  }

  /// F-05: download a media blob (Cloudinary ciphertext) as raw bytes.
  /// Sent without auth headers: the blob lives on the public Cloudinary URL,
  /// and we must not forward the user's bearer token to a third-party CDN.
  Future<Uint8List> fetchBytes(String url) async {
    final uri = Uri.parse(url);
    final response = await _performRequest(() async => http.get(uri), uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to download media (HTTP ${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final requestBody = <String, dynamic>{...?body};

    final response = await _performRequest(
      () async => http.put(
        url,
        headers: await _headers(),
        body: jsonEncode(requestBody),
      ),
      url,
    );

    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final requestBody = <String, dynamic>{...?body};

    final response = await _performRequest(
      () async => http.patch(
        url,
        headers: await _headers(),
        body: jsonEncode(requestBody),
      ),
      url,
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final response = await _performRequest(
      () async => http.delete(url, headers: await _headers()),
      url,
    );

    return _handleResponse(response);
  }

  Future<http.Response> _performRequest(
    Future<http.Response> Function() request,
    Uri url,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException catch (error, stackTrace) {
      CrashlyticsService.recordError(
        error,
        stackTrace,
        reason: 'API request timed out: ${url.path}',
      );
      throw Exception(
        'The YACK server did not respond. Check the backend connection and try again.',
      );
    } on http.ClientException catch (error, stackTrace) {
      CrashlyticsService.recordError(
        error,
        stackTrace,
        reason: 'API connection failed: ${url.path}',
      );
      throw Exception(
        'Unable to reach the YACK server. Check your connection and backend URL.',
      );
    }
  }

  dynamic _handleResponse(http.Response res) {
    final status = res.statusCode;
    final isSuccess = status >= 200 && status < 300;

    if (res.body.trim().isEmpty) {
      if (isSuccess) return null;
      throw ApiException(
        statusCode: status,
        message: 'Server error (HTTP $status)',
      );
    }

    // Always try to decode JSON so we can surface the server's real error message.
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        if (isSuccess) return decoded;
        throw ApiException(
          statusCode: status,
          message: 'Server error (HTTP $status): $res.body',
        );
      }
      json = decoded;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      final errorMessage = 'Invalid response (HTTP $status): ${res.body}';
      final error = ApiException(statusCode: status, message: errorMessage);
      CrashlyticsService.recordError(
        error,
        StackTrace.current,
        reason: errorMessage,
      );
      throw error;
    }

    if (isSuccess) return json;

    // Backend errors are `{ error: "...", code: "..." }`. The error value may
    // be a Map on the admin/review endpoints, so only treat strings as text.
    String message;
    final rawError = json['error'];
    if (rawError is String) {
      message = rawError;
    } else if (rawError is Map) {
      message = rawError['message']?.toString() ??
          rawError['error']?.toString() ??
          'Server error (HTTP $status)';
    } else {
      message = 'Unknown server error (HTTP $status)';
    }
    final error = ApiException(
      statusCode: status,
      code: json['code']?.toString() ?? '',
      message: message,
    );
    CrashlyticsService.recordError(
      error,
      StackTrace.current,
      reason: 'HTTP $status [$error.code]: $error.message',
    );
    throw error;
  }
}
