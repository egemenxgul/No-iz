import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationService(dio);
});

class NotificationService {
  final Dio _dio;

  NotificationService(this._dio);

  Future<List<NotificationModel>> getNotifications({int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get('/api/notifications', queryParameters: {
        'limit': limit,
        'offset': offset,
      });
      final list = response.data['notifications'] as List?;
      if (list == null) return [];
      return list.map((item) => NotificationModel.fromMap(item)).toList();
    } on DioException catch (e) {
      throw _parseError(e, 'Bildirimler alınamadı');
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.post('/api/notifications/$id/read');
    } on DioException catch (e) {
      throw _parseError(e, 'Bildirim okundu işaretlenemedi');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post('/api/notifications/read-all');
    } on DioException catch (e) {
      throw _parseError(e, 'Tüm bildirimler okundu işaretlenemedi');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _dio.delete('/api/notifications/$id');
    } on DioException catch (e) {
      throw _parseError(e, 'Bildirim silinemedi');
    }
  }

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
}

class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  FutureOr<List<NotificationModel>> build() async {
    final service = ref.watch(notificationServiceProvider);
    return service.getNotifications();
  }

  Future<void> refreshNotifications() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(notificationServiceProvider).getNotifications();
    });
  }

  Future<void> markAsRead(String id) async {
    final previousState = state;
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data(list.map((n) {
        if (n.id == id) {
          return n.copyWith(readAt: DateTime.now());
        }
        return n;
      }).toList());
    }

    try {
      await ref.read(notificationServiceProvider).markRead(id);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final previousState = state;
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data(list.map((n) {
        return n.copyWith(readAt: DateTime.now());
      }).toList());
    }

    try {
      await ref.read(notificationServiceProvider).markAllRead();
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final previousState = state;
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data(list.where((n) => n.id != id).toList());
    }

    try {
      await ref.read(notificationServiceProvider).deleteNotification(id);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }
}

final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  NotificationsNotifier.new,
);
