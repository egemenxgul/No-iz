import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

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

  Future<Map<String, dynamic>> login(String id, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email_or_username': id,
        'password': password,
      });
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, 'Giriş yapılamadı');
    }
  }

  Future<Map<String, dynamic>> login2FA(String tempToken, String code) async {
    try {
      final response = await _dio.post('/api/auth/login/2fa', data: {
        'temp_token': tempToken,
        'code': code,
      });
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, '2FA doğrulaması başarısız');
    }
  }

  Future<Map<String, dynamic>> generate2FA() async {
    try {
      final response = await _dio.post('/api/auth/2fa/generate');
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, '2FA oluşturulamadı');
    }
  }

  Future<void> verify2FA(String code) async {
    try {
      await _dio.post('/api/auth/2fa/verify', data: {
        'code': code,
      });
    } on DioException catch (e) {
      throw _parseError(e, '2FA doğrulanamadı');
    }
  }

  Future<Map<String, dynamic>> exportData() async {
    try {
      final response = await _dio.get('/api/users/export');
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, 'Veri dışa aktarılamadı');
    }
  }

  Future<void> deleteAccount(String password) async {
    try {
      await _dio.post('/api/users/delete-account', data: {
        'password': password,
      });
    } on DioException catch (e) {
      throw _parseError(e, 'Hesap silinemedi');
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
    required Map<String, dynamic> signalKeys,
    String? phone,
  }) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
        'display_name': displayName,
        'invite_code': inviteCode,
        'phone': phone ?? '',
        'identity_key': signalKeys['identity_key'],
        'signed_prekey': signalKeys['signed_prekey'],
        'signed_prekey_sig': signalKeys['signed_prekey_sig'],
      });
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, 'Kayıt başarısız');
    }
  }

  Future<Map<String, dynamic>> getUserBundle(String userId) async {
    try {
      final response = await _dio.get('/api/users/$userId/bundle');
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, 'Kullanıcı anahtar demeti alınamadı');
    }
  }

  Future<void> registerDevice({
    required String deviceName,
    required String deviceToken,
    required String platform,
    required String identityKey,
  }) async {
    try {
      await _dio.post('/api/devices/register', data: {
        'device_name': deviceName,
        'device_token': deviceToken,
        'platform': platform,
        'identity_key': identityKey,
      });
    } on DioException catch (e) {
      throw _parseError(e, 'Cihaz kaydedilemedi');
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/api/users/me');
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, 'Profil bilgileri alınamadı');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
  }) async {
    try {
      final response = await _dio.put('/api/users/me', data: {
        'display_name': displayName,
        'bio': bio,
        'avatar_url': avatarUrl,
      });
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e, 'Profil güncellenemedi');
    }
  }

  /// Exchanges the opaque refresh token for a new access + refresh token pair.
  /// Called automatically by the Dio interceptor; can also be invoked manually.
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      // Use a plain Dio instance (no auth header) to avoid loops.
      final plainDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await plainDio.post('/api/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      return response.data; // {access_token, refresh_token}
    } on DioException catch (e) {
      throw _parseError(e, 'Oturum yenilenemedi');
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/api/auth/change-password', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw _parseError(e, 'Şifre değiştirilemedi');
    }
  }

  Future<void> changeEmail({
    required String password,
    required String newEmail,
  }) async {
    try {
      await _dio.post('/api/auth/change-email', data: {
        'password': password,
        'new_email': newEmail,
      });
    } on DioException catch (e) {
      throw _parseError(e, 'E-posta değiştirilemedi');
    }
  }

  /// Web tarayıcısından gösterilen QR kodu mobil cihazla okutulduğunda çağrılır.
  /// [qrToken]       : QR URL içindeki `token` parametresi.
  /// [encryptedPayload]: Kimlik anahtarlarını içeren, AES-GCM ile şifrelenmiş yük.
  /// Backend bu yükü QRHub'a depolar; web tarafı polling ile alır.
  Future<void> qrLink({
    required String qrToken,
    required String encryptedPayload,
  }) async {
    try {
      await _dio.post('/api/auth/qr-link', data: {
        'qr_token': qrToken,
        'encrypted_payload': encryptedPayload,
      });
    } on DioException catch (e) {
      throw _parseError(e, 'QR bağlantısı kurulamadı');
    }
  }
}
