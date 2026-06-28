import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_provider.dart';

final passkeyServiceProvider = Provider((ref) => PasskeyService(ref.watch(dioProvider)));

class PasskeyService {
  final Dio _dio;

  PasskeyService(this._dio);

  Future<Map<String, dynamic>> registerBegin(String username, String email, String displayName, String inviteCode) async {
    final res = await _dio.post('/auth/passkey/register/begin', data: {
      'username': username,
      'email': email,
      'display_name': displayName,
      'invite_code': inviteCode,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> registerFinish(String sessionId, Map<String, dynamic> credential) async {
    final res = await _dio.post('/auth/passkey/register/finish?session_id=$sessionId', data: credential);
    return res.data;
  }

  Future<Map<String, dynamic>> loginBegin(String username) async {
    final res = await _dio.post('/auth/passkey/login/begin', data: {
      'username': username,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> loginFinish(String sessionId, Map<String, dynamic> credential) async {
    final res = await _dio.post('/auth/passkey/login/finish?session_id=$sessionId', data: credential);
    return res.data;
  }

  // NOTE: Full integration with passkeys package requires interpreting the challenge and generating credentials.
  // The passkeys package provides high level methods: `PasskeyAuth.register()` and `PasskeyAuth.authenticate()`
  // Usually the relying party wrapper from `passkeys` handles /begin and /finish if provided with a RelyingPartyServer interface.
}
