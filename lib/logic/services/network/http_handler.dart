import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:yack/logic/services/crashlytics_service.dart';

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

  Future<String?> _getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error, stackTrace) {
      // Push registration must never prevent the underlying API action.
      CrashlyticsService.recordError(
        error,
        stackTrace,
        reason: 'FCM token unavailable while preparing API request',
      );
      return null;
    }
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
    final fcm = await _getFcmToken();
    final requestBody = <String, dynamic>{...?body};
    if (fcm != null) requestBody["fcmToken"] = fcm;

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

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final requestBody = <String, dynamic>{...?body};
    final fcm = await _getFcmToken();
    if (fcm != null) requestBody["fcmToken"] = fcm;

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
    final fcm = await _getFcmToken();
    if (fcm != null) requestBody["fcmToken"] = fcm;

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
      throw Exception('Server error (HTTP $status)');
    }

    // Always try to decode JSON so we can surface the server's real error message.
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        if (isSuccess) return decoded;
        throw Exception('Server error (HTTP $status): $res.body');
      }
      json = decoded;
    } catch (e) {
      if (e is Exception && !isSuccess) {
        rethrow;
      }
      final errorMessage = 'Invalid response (HTTP $status): ${res.body}';
      final error = Exception(errorMessage);
      CrashlyticsService.recordError(
        error,
        StackTrace.current,
        reason: errorMessage,
      );
      throw error;
    }

    if (isSuccess) return json;

    final errorMessage =
        json["error"]?.toString() ?? 'Unknown server error (HTTP $status)';
    final error = Exception(errorMessage);
    CrashlyticsService.recordError(
      error,
      StackTrace.current,
      reason: 'HTTP $status: $errorMessage',
    );
    throw error;
  }
}
