import 'dart:developer' as dart_developer;
import 'package:dio/dio.dart';

class MessageService {
  final Dio _dio;

  MessageService(this._dio);

  String _parseError(DioException e, String defaultMsg) {
    try {
      final data = e.response?.data;
      // TODO(Analytics): Integrate Sentry or Firebase Crashlytics here.
      // e.g., Sentry.captureException(e, stackTrace: e.stackTrace);
      dart_developer.log('Network Error: ${e.message}', error: e, stackTrace: e.stackTrace, name: 'MessageService');
      
      if (data is Map && data.containsKey('error')) {
        return data['error']?.toString() ?? defaultMsg;
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
    } catch (_) {}
    return defaultMsg;
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await _dio.get('/api/conversations');
      final data = response.data['conversations'] as List;
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      throw _parseError(e, 'Konuşmalar alınamadı');
    }
  }

  Future<List<Map<String, dynamic>>> getGroups() async {
    try {
      final response = await _dio.get('/api/groups');
      final data = response.data['groups'] as List;
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      throw _parseError(e, 'Gruplar alınamadı');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String otherUserId) async {
    try {
      final response = await _dio.get('/api/messages', queryParameters: {'with': otherUserId});
      final data = response.data['messages'] as List;
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      throw _parseError(e, 'Mesajlar alınamadı');
    }
  }

  Future<List<Map<String, dynamic>>> getGroupMessages(String groupId) async {
    try {
      final response = await _dio.get('/api/groups/$groupId/messages');
      final data = response.data['messages'] as List;
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      throw _parseError(e, 'Grup mesajları alınamadı');
    }
  }

  Future<Map<String, dynamic>> createGroup(String name, String description) async {
    try {
      final response = await _dio.post('/api/groups', data: {
        'name': name,
        'description': description,
        'is_private': false,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Grup oluşturulamadı');
    }
  }

  Future<Map<String, dynamic>> getGroupDetails(String groupId) async {
    try {
      final response = await _dio.get('/api/groups/$groupId');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Grup detayları alınamadı');
    }
  }

  Future<void> leaveGroup(String groupId) async {
    try {
      await _dio.delete('/api/groups/$groupId/leave');
    } on DioException catch (e) {
      throw _parseError(e, 'Gruptan çıkılamadı');
    }
  }

  Future<List<Map<String, dynamic>>> listGroupMembers(String groupId) async {
    try {
      final response = await _dio.get('/api/groups/$groupId/members');
      final data = response.data['members'] as List;
      return List<Map<String, dynamic>>.from(data);
    } on DioException catch (e) {
      throw _parseError(e, 'Grup üyeleri alınamadı');
    }
  }

  Future<void> kickGroupMember(String groupId, String userId) async {
    try {
      await _dio.delete('/api/groups/$groupId/members/$userId');
    } on DioException catch (e) {
      throw _parseError(e, 'Grup üyesi çıkarılamadı');
    }
  }

  Future<void> promoteGroupMember(String groupId, String userId, String role) async {
    try {
      await _dio.put('/api/groups/$groupId/members/$userId/role', data: {
        'role': role,
      });
    } on DioException catch (e) {
      throw _parseError(e, 'Grup üyesi rolü güncellenemedi');
    }
  }

  Future<Map<String, dynamic>> joinGroupByInvite(String token) async {
    try {
      final response = await _dio.post('/api/groups/join/$token');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Davet linki ile gruba katılım başarısız oldu');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _dio.get('/api/users/search', queryParameters: {'q': query});
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Arama başarısız');
    }
  }

  Future<Map<String, dynamic>> acceptMessageRequest(String otherUserId) async {
    try {
      final response = await _dio.post('/api/friends/accept/$otherUserId');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Mesaj isteği kabul edilemedi');
    }
  }

  Future<Map<String, dynamic>> rejectMessageRequest(String otherUserId) async {
    try {
      final response = await _dio.post('/api/friends/reject/$otherUserId');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Mesaj isteği reddedilemedi');
    }
  }

  Future<Map<String, dynamic>> getFriendStatus(String otherUserId) async {
    try {
      final response = await _dio.get('/api/friends/status', queryParameters: {'with': otherUserId});
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Durum alınamadı');
    }
  }

  Future<Map<String, dynamic>> blockUser(String otherUserId) async {
    try {
      final response = await _dio.post('/api/friends/block/$otherUserId');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Kullanıcı engellenemedi');
    }
  }

  Future<Map<String, dynamic>> unblockUser(String otherUserId) async {
    try {
      final response = await _dio.post('/api/friends/unblock/$otherUserId');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Engeli kaldırma başarısız oldu');
    }
  }

  Future<void> muteChat(String targetId, String duration) async {
    try {
      await _dio.post('/api/messages/mute', data: {
        'target_id': targetId,
        'duration': duration,
      });
    } on DioException catch (e) {
      throw _parseError(e, 'Sohbet sessize alınamadı');
    }
  }

  Future<void> unmuteChat(String targetId) async {
    try {
      await _dio.delete('/api/messages/mute/$targetId');
    } on DioException catch (e) {
      throw _parseError(e, 'Sohbetin sesi açılamadı');
    }
  }

  Future<void> pinMessage(String messageId) async {
    try {
      await _dio.post('/api/messages/$messageId/pin');
    } on DioException catch (e) {
      throw _parseError(e, 'Mesaj sabitlenemedi');
    }
  }

  Future<void> unpinMessage(String messageId) async {
    try {
      await _dio.delete('/api/messages/$messageId/pin');
    } on DioException catch (e) {
      throw _parseError(e, 'Mesaj sabitlemesi kaldırılamadı');
    }
  }
}
