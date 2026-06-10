// Copyright (c) 2026 Egemen GÜL (github.com/egemenxgul)
// Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0)
// See LICENSE in the project root for license information.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz_mobile/core/network/dio_provider.dart';

class CommunityService {
  final Dio _dio;

  CommunityService(this._dio);

  String _parseError(DioException e, String defaultMsg) {
    try {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        return data['error']?.toString() ?? defaultMsg;
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
    } catch (_) {}
    return defaultMsg;
  }

  Future<Map<String, dynamic>> createCommunity({
    required String name,
    required String slug,
    required String description,
    bool isPublic = true,
  }) async {
    try {
      final response = await _dio.post('/api/communities', data: {
        'name': name,
        'slug': slug,
        'description': description,
        'is_public': isPublic,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Topluluk oluşturulamadı');
    }
  }

  Future<List<Map<String, dynamic>>> discoverCommunities({int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '/api/communities/discover',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data['communities'] as List?;
      return List<Map<String, dynamic>>.from(data ?? []);
    } on DioException catch (e) {
      throw _parseError(e, 'Keşfet toplulukları yüklenemedi');
    }
  }

  Future<List<Map<String, dynamic>>> getMyCommunities() async {
    try {
      final response = await _dio.get('/api/communities/me');
      final data = response.data['communities'] as List?;
      return List<Map<String, dynamic>>.from(data ?? []);
    } on DioException catch (e) {
      throw _parseError(e, 'Topluluklarım yüklenemedi');
    }
  }

  Future<Map<String, dynamic>> getCommunityBySlug(String slug) async {
    try {
      final response = await _dio.get('/api/communities/$slug');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Topluluk detayları alınamadı');
    }
  }

  Future<Map<String, dynamic>> joinCommunity(String communityId) async {
    try {
      final response = await _dio.post('/api/communities/$communityId/join');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Topluluğa katılım başarısız oldu');
    }
  }

  Future<void> leaveCommunity(String communityId) async {
    try {
      await _dio.delete('/api/communities/$communityId/leave');
    } on DioException catch (e) {
      throw _parseError(e, 'Topluluktan ayrılamadı');
    }
  }

  Future<List<Map<String, dynamic>>> listCommunityGroups(String communityId) async {
    try {
      final response = await _dio.get('/api/communities/$communityId/groups');
      final data = response.data['groups'] as List?;
      return List<Map<String, dynamic>>.from(data ?? []);
    } on DioException catch (e) {
      throw _parseError(e, 'Topluluk grupları yüklenemedi');
    }
  }

  Future<List<Map<String, dynamic>>> listCommunityPosts(String communityId, {int limit = 50, String? before}) async {
    try {
      final queryParams = {'limit': limit};
      if (before != null) {
        queryParams['before'] = before;
      }
      final response = await _dio.get(
        '/api/communities/$communityId/posts',
        queryParameters: queryParams,
      );
      final data = response.data['posts'] as List?;
      return List<Map<String, dynamic>>.from(data ?? []);
    } on DioException catch (e) {
      throw _parseError(e, 'Topluluk gönderileri yüklenemedi');
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String communityId,
    required String title,
    required String body,
    List<String> mediaUrls = const [],
    int expiresIn = 0,
  }) async {
    try {
      final response = await _dio.post(
        '/api/communities/$communityId/posts',
        data: {
          'title': title,
          'body': body,
          'media_urls': mediaUrls,
          'expires_in': expiresIn,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _parseError(e, 'Gönderi oluşturulamadı');
    }
  }

  Future<void> likePost(String postId) async {
    try {
      await _dio.post('/api/communities/posts/$postId/like');
    } on DioException catch (e) {
      throw _parseError(e, 'Gönderi beğenilemedi');
    }
  }

  Future<void> unlikePost(String postId) async {
    try {
      await _dio.delete('/api/communities/posts/$postId/like');
    } on DioException catch (e) {
      throw _parseError(e, 'Beğeni geri alınamadı');
    }
  }
}

final communityServiceProvider = Provider<CommunityService>((ref) {
  final dio = ref.watch(dioProvider);
  return CommunityService(dio);
});
