import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/subscription_model.dart';
import 'package:flutter/foundation.dart';

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionInfo?>((ref) {
  final dio = ref.watch(dioProvider);
  return SubscriptionNotifier(dio);
});

class SubscriptionNotifier extends StateNotifier<SubscriptionInfo?> {
  final dynamic _dio; // Dio type

  SubscriptionNotifier(this._dio) : super(null) {
    fetchSubscription();
  }

  Future<void> fetchSubscription() async {
    try {
      final response = await _dio.get('/economy/subscription');
      if (response.statusCode == 200) {
        state = SubscriptionInfo.fromJson(response.data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to fetch subscription: $e');
    }
  }

  Future<bool> subscribe(String tier) async {
    try {
      final response = await _dio.post('/economy/subscribe', data: {'tier': tier});
      if (response.statusCode == 200) {
        await fetchSubscription();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to subscribe: $e');
      return false;
    }
  }
}
