import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../constants/app_constants.dart';

const _storage = FlutterSecureStorage();

/// A separate Dio instance (no auth interceptor) used ONLY for the refresh-token
/// call — prevents infinite retry loops when the main Dio encounters a 401.
final _refreshDio = Dio(BaseOptions(
  baseUrl: AppConstants.baseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
));

/// Mutex state for concurrent 401 handling.
/// When a refresh is in-flight, all subsequent 401s wait on this completer
/// instead of triggering duplicate refresh requests.
bool _isRefreshing = false;
Completer<String?>? _refreshCompleter;

/// A provider that exposes a callback to sign the user out.
/// Set from the auth layer so the interceptor can trigger navigation-level logout.
typedef LogoutCallback = Future<void> Function();
LogoutCallback? _onForceLogout;

/// Call this once at app startup (e.g., from auth provider) to wire up the
/// force-logout callback so the interceptor can redirect to login.
void registerLogoutCallback(LogoutCallback cb) => _onForceLogout = cb;

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    // ── 1. Attach access token on every outbound request ─────────────
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },

    // ── 2. Transparent token refresh on 401 ──────────────────────────
    onError: (DioException e, handler) async {
      // Only handle 401 Unauthorized; skip the refresh endpoint itself.
      final isRefreshCall =
          e.requestOptions.path.contains('/api/auth/refresh');
      if (e.response?.statusCode != 401 || isRefreshCall) {
        return handler.next(e);
      }

      // ── Mutex: if a refresh is already in-flight, wait for it ──────
      if (_isRefreshing) {
        try {
          // Wait for the in-flight refresh; get the new access token.
          final newToken = await _refreshCompleter!.future;
          if (newToken == null) return handler.next(e);

          // Retry with the token obtained by the other request.
          final retryOpts = e.requestOptions;
          retryOpts.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await dio.fetch(retryOpts);
          return handler.resolve(retryResponse);
        } catch (_) {
          return handler.next(e);
        }
      }

      // ── This request "wins" the mutex — perform the refresh ─────────
      _isRefreshing = true;
      _refreshCompleter = Completer<String?>();

      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        _isRefreshing = false;
        _refreshCompleter!.complete(null);
        await _handleForceLogout();
        return handler.next(e);
      }

      try {
        final response = await _refreshDio.post(
          '/api/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        final newAccess = response.data['access_token'] as String;
        final newRefresh = response.data['refresh_token'] as String;

        // Persist rotated tokens.
        await Future.wait([
          _storage.write(key: 'access_token', value: newAccess),
          _storage.write(key: 'refresh_token', value: newRefresh),
        ]);

        // Signal waiting requests.
        _refreshCompleter!.complete(newAccess);
        _isRefreshing = false;
        _refreshCompleter = null;

        // Retry the original request.
        final retryOpts = e.requestOptions;
        retryOpts.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await dio.fetch(retryOpts);
        return handler.resolve(retryResponse);
      } on DioException catch (refreshErr) {
        // Refresh itself failed — token is expired or revoked.
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        _refreshCompleter = null;

        if (kDebugMode) {
          debugPrint('[DioProvider] Refresh failed: ${refreshErr.message}');
        }

        await _clearTokens();
        await _handleForceLogout();
        return handler.next(e);
      }
    },
  ));

  return dio;
});

/// Removes both tokens from secure storage.
Future<void> _clearTokens() async {
  await Future.wait([
    _storage.delete(key: 'access_token'),
    _storage.delete(key: 'refresh_token'),
  ]);
}

/// Invokes the registered logout callback when token refresh fails.
Future<void> _handleForceLogout() async {
  if (_onForceLogout != null) {
    try {
      await _onForceLogout!();
    } catch (e) {
      if (kDebugMode) debugPrint('[DioProvider] Force logout error: $e');
    }
  }
  
  // Safe fallback to force navigation to login using root navigator key
  final context = rootNavigatorKey.currentContext;
  if (context != null) {
    context.go('/login');
  }
}
