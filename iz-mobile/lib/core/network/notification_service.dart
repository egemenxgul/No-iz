import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/callkit_service.dart';
import 'dio_provider.dart';

// ── Background Handler ────────────────────────────────────────────────────────
// MUST be a top-level function (not a class method) and annotated with
// @pragma('vm:entry-point') so it survives tree-shaking in release builds.
// It runs in a separate Dart isolate — no BuildContext, no Riverpod access.
// Security: we intentionally do NOT show message content in notifications.
// Only sender metadata (name / conversation ID) is included.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // NOTE: Firebase.initializeApp() is called in main() before this can fire,
  // so we do NOT need to call it again here.
  if (kDebugMode) {
    debugPrint('[FCM Background] id=${message.messageId} '
        'data=${message.data}');
  }
  
  // UX-8: Intercept background "call_offer" to wake up CallKit
  if (message.data['type'] == 'call_offer') {
    final callId = message.data['call_id'] as String?;
    final callerId = message.data['caller_id'] as String?;
    final callerName = message.data['caller_name'] as String? ?? 'Bilinmeyen Numara';
    final callTypeStr = message.data['call_type'] as String? ?? 'audio';
    final isVideo = callTypeStr == 'video';

    if (callId != null && callerId != null) {
      if (kDebugMode) debugPrint('[FCM Background] Waking up CallKit for $callId');
      await CallKitService().showIncomingCall(
        callId: callId,
        callerName: callerName,
        callerHandle: '@iz_user', // Fallback or could be sent via push
        isVideo: isVideo,
        extra: {
          'sdp': message.data['sdp'],
          'caller_id': callerId,
          'call_type': callTypeStr,
          'decline_token': message.data['decline_token'],
        },
      );
    }
  }

  // Background data-only messages are handled automatically by the OS
  // notification system using the `notification` payload set server-side.
  // We don't perform any additional processing here to keep the isolate minimal.
}

// ── Deep Link Router ──────────────────────────────────────────────────────────
// Parses an FCM RemoteMessage and returns the in-app route string, or null.
String? _routeFromMessage(RemoteMessage? message) {
  if (message == null) return null;
  final senderId = message.data['sender_id'] as String?;
  if (senderId != null && senderId.isNotEmpty) {
    return '/app/messages/$senderId';
  }
  return '/app';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationService(dio);
});

/// Callback type used by [NotificationService] to trigger in-app navigation.
typedef DeepLinkCallback = void Function(String route);

class NotificationService {
  final Dio _dio;
  bool _initialized = false;
  String? _currentDeviceToken;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Set by main.dart after the router is ready.
  DeepLinkCallback? _onDeepLink;

  NotificationService(this._dio);

  /// Registers the navigation callback.
  /// Call this once the GoRouter is available (e.g., in IzApp.build).
  void setDeepLinkCallback(DeepLinkCallback cb) => _onDeepLink = cb;

  /// Initializes push notifications:
  ///   1. Requests OS permission.
  ///   2. Retrieves the FCM token.
  ///   3. Registers the token with the backend.
  ///   4. Subscribes to foreground + tap message streams.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null && _onDeepLink != null) {
            _onDeepLink!(details.payload!);
          }
        },
      );

      // Request permission (required on iOS; shown as a dialog).
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) debugPrint('[FCM] Permission denied');
        return;
      }

      // Retrieve the FCM registration token.
      _currentDeviceToken = await messaging.getToken();
      if (kDebugMode) debugPrint('[FCM] Token: $_currentDeviceToken');

      // Listen for token refresh (e.g., app reinstall or token rotation).
      messaging.onTokenRefresh.listen((newToken) {
        _currentDeviceToken = newToken;
        registerDevice();
      });

      // Foreground messages — show an in-app banner (not a system notification).
      FirebaseMessaging.onMessage.listen(_handleForeground);

      // User tapped a notification while app was in background (but running).
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // App launched cold by tapping a notification.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleTap(initialMessage);

      _initialized = true;
      await registerDevice();
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] init error: $e');
    }
  }

  /// Sends the FCM token to the backend `/api/devices/register`.
  Future<void> registerDevice() async {
    if (_currentDeviceToken == null) return;

    try {
      final platform = Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'web');
      final deviceName = Platform.isIOS ? 'Apple Device' : (Platform.isAndroid ? 'Android Device' : 'Web Client');

      await _dio.post('/api/devices/register', data: {
        'device_name': deviceName,
        'device_token': _currentDeviceToken,
        'platform': platform,
      });

      if (kDebugMode) debugPrint('[FCM] Device registered ($platform)');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] register error: $e');
    }
  }

  // ── Private Handlers ────────────────────────────────────────────────────────

  /// Handles foreground messages — the app is open.
  /// Security: we do NOT display message content (E2EE — server is blind).
  void _handleForeground(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM Foreground] from=${message.data["sender_id"]}');
    }
    
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // channel id
            'High Importance Notifications', // channel name
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: _routeFromMessage(message),
      );
    }
  }

  /// Handles notification taps — routes to the relevant conversation.
  void _handleTap(RemoteMessage message) {
    final route = _routeFromMessage(message);
    if (route != null && _onDeepLink != null) {
      _onDeepLink!(route);
    }
  }
}
