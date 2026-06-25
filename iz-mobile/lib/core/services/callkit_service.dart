import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

/// UX-8: CallKit (iOS) + ConnectionService (Android) entegrasyonu.
///
/// Bu servis gelen arama bildirimlerini platform-native UI üzerinden
/// gösterir: iOS'ta kilitli ekranda CallKit UI, Android'de bağlantı
/// ekranı (ConnectionService).
class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

  /// Gelen bir arama için platform native arama ekranını gösterir.
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerHandle, // username or phone
    String? callerAvatar,
    bool isVideo = false,
  }) async {
    try {
      final params = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'iz',
        avatar: callerAvatar,
        handle: callerHandle,
        type: isVideo ? 1 : 0, // 0 = audio, 1 = video
        duration: 45000, // 45 seconds ringing timeout
        textAccept: 'Kabul Et',
        textDecline: 'Reddet',
        missedCallNotification: NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Cevapsız arama',
          callbackText: 'Geri ara',
        ),
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0A0A0A',
          backgroundUrl: '',
          actionColor: '#8B5CF6',
          textColor: '#FFFFFF',
          incomingCallNotificationChannelName: 'Gelen Aramalar',
          missedCallNotificationChannelName: 'Cevapsız Aramalar',
        ),
        ios: IOSParams(
          iconName: 'CallKitLogo',
          handleType: '',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 5,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(params);
      if (kDebugMode) debugPrint('[CallKit] Gelen arama gösterildi: $callerName ($callId)');
    } catch (e) {
      if (kDebugMode) debugPrint('[CallKit] Hata: $e');
    }
  }

  /// Aktif aramayı bitirir.
  Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      if (kDebugMode) debugPrint('[CallKit] endCall Hata: $e');
    }
  }

  /// Tüm aktif aramaları bitirir (uygulama kapanırken).
  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      if (kDebugMode) debugPrint('[CallKit] endAllCalls Hata: $e');
    }
  }

  /// Aramayı aktif (konuşulan) duruma geçirir.
  Future<void> setCallActive(String callId) async {
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (e) {
      if (kDebugMode) debugPrint('[CallKit] setCallActive Hata: $e');
    }
  }

  /// Yeni giden arama başlatır (iOS CallKit'te outgoing arama UI).
  Future<void> startOutgoingCall({
    required String callId,
    required String calleeName,
    required String calleeHandle,
    bool isVideo = false,
  }) async {
    try {
      final params = CallKitParams(
        id: callId,
        nameCaller: calleeName,
        appName: 'iz',
        handle: calleeHandle,
        type: isVideo ? 1 : 0,
        duration: 45000,
        textAccept: 'Kabul Et',
        textDecline: 'Kapat',
        android: AndroidParams(
          isCustomNotification: false,
          isShowLogo: false,
          backgroundColor: '#0A0A0A',
          actionColor: '#8B5CF6',
          textColor: '#FFFFFF',
          incomingCallNotificationChannelName: 'Aramalar',
          missedCallNotificationChannelName: 'Cevapsız Aramalar',
        ),
        ios: IOSParams(
          iconName: 'CallKitLogo',
          handleType: '',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 5,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      await FlutterCallkitIncoming.startCall(params);
    } catch (e) {
      if (kDebugMode) debugPrint('[CallKit] startOutgoingCall Hata: $e');
    }
  }

  /// Generates a unique call ID.
  static String newCallId() => const Uuid().v4();
}
