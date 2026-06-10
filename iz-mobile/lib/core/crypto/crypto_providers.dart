import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'crypto_service.dart';
import 'ratchet_service.dart';
import 'session_manager.dart';
import 'identity_manager.dart';

final cryptoServiceProvider = Provider((ref) => CryptoService());
final ratchetServiceProvider = Provider((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  return RatchetService(crypto);
});

final storageProvider = Provider((ref) => const FlutterSecureStorage());

final identityManagerProvider = Provider((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final storage = ref.watch(storageProvider);
  return IdentityManager(crypto, storage);
});

final sessionManagerProvider = Provider((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final ratchet = ref.watch(ratchetServiceProvider);
  return SessionManager(crypto, ratchet);
});
