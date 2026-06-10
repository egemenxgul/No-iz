import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';

class ReportService {
	final Dio _dio;

	ReportService(this._dio);

	Future<void> submitReport({
		String? reportedUserId,
		String? reportedCommunityId,
		required String reason,
		required String description,
	}) async {
		await _dio.post('/api/reports', data: {
			if (reportedUserId != null) 'reported_user_id': reportedUserId,
			if (reportedCommunityId != null) 'reported_community_id': reportedCommunityId,
			'reason': reason,
			'description': description,
		});
	}
}

final reportServiceProvider = Provider<ReportService>((ref) {
	final dio = ref.watch(dioProvider);
	return ReportService(dio);
});
