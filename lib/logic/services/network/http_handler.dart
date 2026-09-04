import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:yack/logic/services/crashlytics_service.dart';

class HttpHandler {
  static final HttpHandler _instance = HttpHandler._internal();
  factory HttpHandler() => _instance;

  HttpHandler._internal();

  static const Duration _requestTimeout = Duration(seconds: 20);

  // Backend base URL.
  // Override at build/run time with:
  //   flutter run --dart-define=API_BASE_URL=https://your-backend.example
  // Keep the default in sync with where you actually host the backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://yack.leapcell.app',
  );

  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    return await user.getIdToken(true);
  }

  Future<String?> _getFcmToken() async {
    return await FirebaseMessaging.instance.getToken();
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
    body ??= {};
    if (fcm != null) body["fcmToken"] = fcm;

    final response = await http
        .post(url, headers: await _headers(), body: jsonEncode(body))
        .timeout(_requestTimeout);

    return _handleResponse(response);
  }

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final response = await http
        .get(url, headers: await _headers())
        .timeout(_requestTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse("$baseUrl$endpoint");

    body ??= {};
    final fcm = await _getFcmToken();
    if (fcm != null) body["fcmToken"] = fcm;

    final response = await http
        .put(url, headers: await _headers(), body: jsonEncode(body))
        .timeout(_requestTimeout);

    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse("$baseUrl$endpoint");

    body ??= {};
    final fcm = await _getFcmToken();
    if (fcm != null) body["fcmToken"] = fcm;

    final response = await http
        .patch(url, headers: await _headers(), body: jsonEncode(body))
        .timeout(_requestTimeout);

    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final response = await http
        .delete(url, headers: await _headers())
        .timeout(_requestTimeout);

    return _handleResponse(response);
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
