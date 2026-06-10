import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_provider.dart';
import 'account_provider.dart';
import 'auth_service.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isInitialized;
  final String? error;
  final String? userId;

  final bool requires2FA;
  final String? tempToken;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
    this.userId,
    this.requires2FA = false,
    this.tempToken,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    String? userId,
    bool? requires2FA,
    String? tempToken,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
      userId: userId ?? this.userId,
      requires2FA: requires2FA ?? this.requires2FA,
      tempToken: tempToken ?? this.tempToken,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  @override
  AuthState build() {
    _checkAuth();
    // Wire the Dio interceptor's force-logout so it can clear auth state
    // when the refresh token itself is expired or revoked.
    registerLogoutCallback(() async {
      await logout();
    });
    return AuthState();
  }

  Future<void> _checkAuth() async {
    try {
      // 1. Ensure accountProvider loads all stored accounts first!
      await ref.read(accountProvider.notifier).loadAccounts();

      // 2. Read active authentication tokens
      final token = await _storage.read(key: 'access_token');
      final userId = await _storage.read(key: 'user_id');

      if (token != null && userId != null) {
        state = state.copyWith(
          isAuthenticated: true,
          isInitialized: true,
          userId: userId,
        );
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          isInitialized: true,
        );
      }
    } catch (_) {
      state = state.copyWith(
        isAuthenticated: false,
        isInitialized: true,
      );
    }
  }

  Future<void> login(String id, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await ref.read(authServiceProvider).login(id, password);
      
      final bool requires2fa = data['requires_2fa'] ?? false;
      if (requires2fa) {
        state = state.copyWith(
          isLoading: false,
          requires2FA: true,
          tempToken: data['temp_token'],
        );
        return;
      }

      final String token = data['access_token'];
      final String refreshToken = data['refresh_token'];
      final String userId = data['user_id'];
      final String username = data['username'];
      final String displayName = data['display_name'] ?? username;
      final String avatarUrl = data['avatar_url'] ?? '';
      final String bio = data['bio'] ?? '';

      // Save to active tokens in secure storage
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'refresh_token', value: refreshToken);
      await _storage.write(key: 'user_id', value: userId);

      // Create account detail and add it to accountProvider
      final newAccount = AccountInfo(
        id: userId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
      );
      
      await ref.read(accountProvider.notifier).addOrUpdateAccount(
        newAccount,
        accessToken: token,
        refreshToken: refreshToken,
      );

      state = state.copyWith(
        isLoading: false, 
        isAuthenticated: true,
        isInitialized: true,
        userId: userId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login2FA(String code) async {
    final tempToken = state.tempToken;
    if (tempToken == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await ref.read(authServiceProvider).login2FA(tempToken, code);
      
      final String token = data['access_token'];
      final String refreshToken = data['refresh_token'];
      final String userId = data['user_id'];
      final String username = data['username'];
      final String displayName = data['display_name'] ?? username;
      final String avatarUrl = data['avatar_url'] ?? '';
      final String bio = data['bio'] ?? '';

      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'refresh_token', value: refreshToken);
      await _storage.write(key: 'user_id', value: userId);

      final newAccount = AccountInfo(
        id: userId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
      );
      
      await ref.read(accountProvider.notifier).addOrUpdateAccount(
        newAccount,
        accessToken: token,
        refreshToken: refreshToken,
      );

      state = state.copyWith(
        isLoading: false, 
        isAuthenticated: true,
        isInitialized: true,
        requires2FA: false,
        tempToken: null,
        userId: userId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSession({required bool isAuthenticated, String? userId}) {
    state = state.copyWith(
      isAuthenticated: isAuthenticated,
      userId: userId,
    );
  }

  Future<void> logout() async {
    final activeId = ref.read(accountProvider).activeAccountId;
    if (activeId != null) {
      // Trigger the account-specific log out / switch
      await ref.read(accountProvider.notifier).removeAccount(activeId);
    } else {
      // Direct absolute logout fallback
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'user_id');
      await _storage.delete(key: 'active_account_id');
      state = AuthState(isInitialized: true);
    }
  }
}

final authServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return AuthService(dio);
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
