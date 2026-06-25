import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_provider.dart';

final appleAuthServiceProvider = Provider((ref) => AppleAuthService(ref.watch(dioProvider)));

class AppleAuthService {
  final Dio _dio;

  AppleAuthService(this._dio);

  /// Initiates the Apple Sign In flow and sends the token to our backend
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final fullName = credential.givenName != null || credential.familyName != null
          ? '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim()
          : '';

      // Send to our backend
      final response = await _dio.post(
        '/auth/apple',
        data: {
          'identity_token': credential.identityToken,
          'user_id': credential.userIdentifier,
          'email': credential.email ?? '',
          'full_name': fullName,
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppleAuth] Error: $e');
      rethrow;
    }
  }

  Future<bool> isAvailable() async {
    return await SignInWithApple.isAvailable();
  }
}
