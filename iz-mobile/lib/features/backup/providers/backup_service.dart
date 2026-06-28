import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';

class BackupService {
	final Dio _dio;

	BackupService(this._dio);

	Future<void> saveBackup(String encryptedBlob, String salt) async {
		await _dio.post('/api/backup', data: {
			'encrypted_blob': encryptedBlob,
			'salt': salt,
		});
	}

	Future<Map<String, dynamic>?> getBackup() async {
		try {
			final res = await _dio.get('/api/backup');
			return res.data as Map<String, dynamic>;
		} on DioException catch (e) {
			if (e.response?.statusCode == 404) {
				return null; // no backup found
			}
			rethrow;
		}
	}

	Future<void> saveVaultMessages(List<Map<String, dynamic>> messages) async {
		await _dio.post('/api/vault', data: {'messages': messages});
	}
}

final backupServiceProvider = Provider<BackupService>((ref) {
	final dio = ref.watch(dioProvider);
	return BackupService(dio);
});
