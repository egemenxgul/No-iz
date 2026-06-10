import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../constants/app_constants.dart';

/// WebSocket connection state exposed to the UI.
enum WsConnectionState { disconnected, connecting, connected }

/// Manages the real-time WebSocket connection with:
///   - Exponential backoff + jitter reconnect
///   - Network-aware reconnect (connectivity_plus)
///   - Client-side heartbeat ping/pong (30 s interval, 10 s timeout)
///   - Manual close detection (no reconnect after explicit disconnect())
class WebSocketService {
  WebSocketChannel? _channel;
  WsConnectionState _state = WsConnectionState.disconnected;
  bool _manuallyClosed = false;

  // ── Backoff ───────────────────────────────────────────────────────
  int _retryCount = 0;
  final Duration _minDelay = const Duration(seconds: 1);
  final Duration _maxDelay = const Duration(seconds: 30);
  Timer? _reconnectTimer;

  // ── Heartbeat ─────────────────────────────────────────────────────
  /// How often we send a ping frame.
  static const _heartbeatInterval = Duration(seconds: 30);
  /// How long we wait for a pong before treating the connection as dead.
  static const _pongTimeout = Duration(seconds: 10);
  Timer? _heartbeatTimer;
  Timer? _pongTimeoutTimer;

  // ── Connectivity ──────────────────────────────────────────────────
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ── Callbacks ─────────────────────────────────────────────────────
  final Future<String?> Function() tokenProvider;
  final void Function(Map<String, dynamic>) onMessageReceived;
  final void Function(WsConnectionState)? onStateChanged;

  WebSocketService({
    required this.tokenProvider,
    required this.onMessageReceived,
    this.onStateChanged,
  }) {
    _subscribeToConnectivity();
  }

  // ── Public API ────────────────────────────────────────────────────

  WsConnectionState get connectionState => _state;
  bool get isConnected => _state == WsConnectionState.connected;

  void connect() async {
    if (_state != WsConnectionState.disconnected) return;
    _manuallyClosed = false;
    _setState(WsConnectionState.connecting);

    try {
      final token = await tokenProvider();
      if (token == null) {
        _setState(WsConnectionState.disconnected);
        _scheduleReconnect();
        return;
      }

      final uri = Uri.parse('${AppConstants.wsUrl}?token=$token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          // First message confirms the connection is alive.
          if (_state != WsConnectionState.connected) {
            _setState(WsConnectionState.connected);
            _retryCount = 0;
            _startHeartbeat();
          }
          _handleIncomingFrame(data);
        },
        onDone: () => _handleDisconnect(),
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );

      // Treat a successful channel creation as "connecting" — the state
      // moves to "connected" on the first received frame (or heartbeat pong).
    } catch (e) {
      if (kDebugMode) debugPrint('[WS] connect error: $e');
      _setState(WsConnectionState.disconnected);
      _handleDisconnect();
    }
  }

  void sendMessage(String type, Map<String, dynamic> payload) {
    if (!isConnected || _channel == null) return;
    final envelope = jsonEncode({'type': type, 'payload': payload});
    _channel!.sink.add(envelope);
  }

  void disconnect() {
    _manuallyClosed = true;
    _cleanup();
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ── Incoming Frame Handling ───────────────────────────────────────

  void _handleIncomingFrame(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = decoded['type'] as String?;

      // Cancel pong timeout — server is alive.
      if (type == 'pong') {
        _pongTimeoutTimer?.cancel();
        _pongTimeoutTimer = null;
        return; // Do not propagate pong frames to the app layer.
      }

      onMessageReceived(decoded);
    } catch (e) {
      if (kDebugMode) debugPrint('[WS] frame decode error: $e');
    }
  }

  // ── Disconnect / Reconnect ────────────────────────────────────────

  void _handleDisconnect() {
    _setState(WsConnectionState.disconnected);
    _stopHeartbeat();
    _channel = null;
    if (!_manuallyClosed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manuallyClosed) return;
    _reconnectTimer?.cancel();

    // delay = min(minDelay × 2^retryCount, maxDelay)
    final exponent = min(_retryCount, 10).toDouble();
    final rawDelayMs = (_minDelay.inMilliseconds * pow(2, exponent)).toDouble();
    final cappedMs = min(rawDelayMs, _maxDelay.inMilliseconds.toDouble());

    // Add ±15% jitter to prevent thundering-herd.
    final jitter = 0.85 + Random().nextDouble() * 0.30;
    final finalDelay = Duration(milliseconds: (cappedMs * jitter).round());

    _retryCount++;
    if (kDebugMode) {
      debugPrint('[WS] reconnect in ${finalDelay.inMilliseconds}ms '
          '(attempt $_retryCount)');
    }
    _reconnectTimer = Timer(finalDelay, connect);
  }

  // ── Heartbeat ─────────────────────────────────────────────────────

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendPing());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  void _sendPing() {
    if (!isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'ping'}));

    // If no pong arrives within _pongTimeout, treat connection as stale.
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = Timer(_pongTimeout, () {
      if (kDebugMode) debugPrint('[WS] pong timeout — forcing reconnect');
      _channel?.sink.close(status.goingAway);
      _handleDisconnect();
    });
  }

  // ── Connectivity ──────────────────────────────────────────────────

  void _subscribeToConnectivity() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) => _onNetworkChange(results));
  }

  void _onNetworkChange(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (kDebugMode) debugPrint('[WS] network change: $results');

    if (hasNetwork && _state == WsConnectionState.disconnected && !_manuallyClosed) {
      // Network came back — cancel pending backoff timer and reconnect immediately.
      _reconnectTimer?.cancel();
      _retryCount = 0; // Reset backoff on genuine network recovery.
      connect();
    } else if (!hasNetwork && isConnected) {
      // Network went away — close gracefully; reconnect will trigger when it returns.
      _channel?.sink.close(status.goingAway);
      _handleDisconnect();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  void _setState(WsConnectionState s) {
    _state = s;
    onStateChanged?.call(s);
  }

  void _cleanup() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _channel?.sink.close(status.goingAway);
    _state = WsConnectionState.disconnected;
    _channel = null;
  }
}
