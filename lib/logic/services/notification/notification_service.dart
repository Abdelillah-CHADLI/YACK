import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/data/db/models/mediaFile.dart';
import 'package:yack/data/db/models/message.dart';
import 'package:yack/data/repositories/isar_adapter.dart';
import 'package:yack/data/db/models/notification.dart';
import 'package:yack/firebase_options.dart';
import 'package:yack/logic/services/notification/contract_notification_handler.dart';
import 'package:yack/logic/services/notification/notification_router_service.dart';
import 'package:yack/logic/services/user/user_service.dart';

/// Service for handling push notifications from Firebase Cloud Messaging.
/// Parses notification data and saves to local Isar database.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Contract notification handler for real-time contract events
  final ContractNotificationHandler contractHandler =
      ContractNotificationHandler();
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Initialize FCM and set up handlers
  Future<void> initialize() async {
    // Request notification permissions
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
      (token) => unawaited(_registerToken(token)),
    );

    // Initialize contract notification handler
    contractHandler.initialize();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background/terminated message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Handle foreground messages - save to Isar and optionally show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _saveNotificationToIsar(message);
    // TODO: Show local notification if needed
  }

  /// Handle when user taps on a notification
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    await NotificationRouterService.handleNotificationTap(message.data);
  }

  /// Parse and save notification to Isar database
  Future<AppNotification> _saveNotificationToIsar(RemoteMessage message) async {
    final notification = AppNotification.fromFcmData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    return await saveNotificationToIsar(notification);
  }

  /// Get FCM token for registration with backend
  Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  Future<void> registerCurrentToken() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {
      // Push is optional and must not block sign-in or contract access.
    }
  }

  Future<void> _registerToken(String token) async {
    if (FirebaseAuth.instance.currentUser == null || token.isEmpty) return;
    try {
      await UserService().registerFcmToken(token);
    } catch (_) {
      // The next refresh or authenticated app start retries registration.
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final directory = await getApplicationDocumentsDirectory();
  final backgroundDatabase = await Isar.open([
    ContractSchema,
    MessageSchema,
    MediaFileSchema,
    AppNotificationSchema,
  ], directory: directory.path);
  final notification = AppNotification.fromFcmData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );
  await backgroundDatabase.writeTxn(() async {
    await backgroundDatabase.appNotifications.put(notification);
  });
}
