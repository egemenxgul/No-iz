import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_provider.dart';

class AccountInfo {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? subscriptionTier;

  AccountInfo({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.subscriptionTier,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'bio': bio,
    'subscription_tier': subscriptionTier,
  };

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
    id: json['id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    subscriptionTier: json['subscription_tier'] as String?,
  );

  AccountInfo copyWith({
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? subscriptionTier,
  }) {
    return AccountInfo(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
    );
  }
}

class AccountState {
  final String? activeAccountId;
  final List<AccountInfo> accounts;

  AccountState({this.activeAccountId, this.accounts = const []});

  AccountState copyWith({String? activeAccountId, List<AccountInfo>? accounts}) {
    return AccountState(
      activeAccountId: activeAccountId ?? this.activeAccountId,
      accounts: accounts ?? this.accounts,
    );
  }
}

class AccountNotifier extends Notifier<AccountState> {
  final _storage = const FlutterSecureStorage();

  @override
  AccountState build() {
    return AccountState();
  }

  Future<void> loadAccounts() async {
    final activeId = await _storage.read(key: 'active_account_id');
    final accountsJson = await _storage.read(key: 'stored_accounts');
    List<AccountInfo> accountsList = [];

    if (accountsJson != null) {
      try {
        final decoded = jsonDecode(accountsJson) as List;
        accountsList = decoded.map((item) => AccountInfo.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    state = AccountState(
      activeAccountId: activeId,
      accounts: accountsList,
    );
  }

  Future<void> switchAccount(String accountId) async {
    // 1. Write the new active account ID
    await _storage.write(key: 'active_account_id', value: accountId);

    // 2. Load the tokens for the new account and copy them to active session keys
    final accAccessToken = await _storage.read(key: 'access_token_$accountId');
    final accRefreshToken = await _storage.read(key: 'refresh_token_$accountId');
    final accUserId = await _storage.read(key: 'user_id_$accountId');

    if (accAccessToken != null) {
      await _storage.write(key: 'access_token', value: accAccessToken);
    } else {
      await _storage.delete(key: 'access_token');
    }

    if (accRefreshToken != null) {
      await _storage.write(key: 'refresh_token', value: accRefreshToken);
    } else {
      await _storage.delete(key: 'refresh_token');
    }

    if (accUserId != null) {
      await _storage.write(key: 'user_id', value: accUserId);
    } else {
      await _storage.delete(key: 'user_id');
    }

    // 3. Update accountProvider state
    state = state.copyWith(activeAccountId: accountId);

    // 4. Force refresh of the auth session
    ref.read(authProvider.notifier).setSession(
      isAuthenticated: accAccessToken != null,
      userId: accUserId,
    );
  }

  Future<void> addOrUpdateAccount(
    AccountInfo info, {
    String? accessToken,
    String? refreshToken,
  }) async {
    final existingIndex = state.accounts.indexWhere((acc) => acc.id == info.id);
    List<AccountInfo> newAccounts;

    if (existingIndex >= 0) {
      newAccounts = List.from(state.accounts);
      newAccounts[existingIndex] = info;
    } else {
      // Restrict to max 2 accounts
      if (state.accounts.length >= 2) return;
      newAccounts = [...state.accounts, info];
    }

    // Save tokens specifically for this account ID
    if (accessToken != null) {
      await _storage.write(key: 'access_token_${info.id}', value: accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token_${info.id}', value: refreshToken);
    }
    await _storage.write(key: 'user_id_${info.id}', value: info.id);

    state = state.copyWith(accounts: newAccounts);
    await _storage.write(
      key: 'stored_accounts',
      value: jsonEncode(newAccounts.map((e) => e.toJson()).toList()),
    );

    await switchAccount(info.id);
  }

  Future<void> removeAccount(String accountId) async {
    // Delete account-specific storage
    await _storage.delete(key: 'access_token_$accountId');
    await _storage.delete(key: 'refresh_token_$accountId');
    await _storage.delete(key: 'user_id_$accountId');

    // Remove from the accounts list
    final newAccounts = state.accounts.where((acc) => acc.id != accountId).toList();
    await _storage.write(
      key: 'stored_accounts',
      value: jsonEncode(newAccounts.map((e) => e.toJson()).toList()),
    );

    if (newAccounts.isNotEmpty) {
      state = state.copyWith(accounts: newAccounts);
      // Automatically switch to the remaining account!
      await switchAccount(newAccounts.first.id);
    } else {
      // Clear active credentials completely
      await _storage.delete(key: 'active_account_id');
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'user_id');

      state = AccountState(accounts: []);
      ref.read(authProvider.notifier).setSession(
        isAuthenticated: false,
        userId: null,
      );
    }
  }

  Future<void> updateProfileLocal(
    String accountId, {
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final existingIndex = state.accounts.indexWhere((acc) => acc.id == accountId);
    if (existingIndex < 0) return;

    final updatedAccount = state.accounts[existingIndex].copyWith(
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
    );

    final newAccounts = List<AccountInfo>.from(state.accounts);
    newAccounts[existingIndex] = updatedAccount;

    state = state.copyWith(accounts: newAccounts);
    await _storage.write(
      key: 'stored_accounts',
      value: jsonEncode(newAccounts.map((e) => e.toJson()).toList()),
    );
  }
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(AccountNotifier.new);
