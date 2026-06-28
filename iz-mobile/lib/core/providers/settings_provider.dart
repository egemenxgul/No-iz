import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:battery_plus/battery_plus.dart';

const _storage = FlutterSecureStorage();

enum StorageMode { device, cloud, smart }

class AppSettings {
  final bool performanceMode;
  final bool compressMedia;
  final bool autoBackup;
  final StorageMode storageMode;

  AppSettings({
    this.performanceMode = false,
    this.compressMedia = true,
    this.autoBackup = false,
    this.storageMode = StorageMode.smart,
  });

  AppSettings copyWith({
    bool? performanceMode,
    bool? compressMedia,
    bool? autoBackup,
    StorageMode? storageMode,
  }) {
    return AppSettings(
      performanceMode: performanceMode ?? this.performanceMode,
      compressMedia: compressMedia ?? this.compressMedia,
      autoBackup: autoBackup ?? this.autoBackup,
      storageMode: storageMode ?? this.storageMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
    _monitorBattery();
  }

  void _monitorBattery() {
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) async {
      if (state == BatteryState.discharging) {
        final level = await _battery.batteryLevel;
        if (level <= 20 && !this.state.performanceMode) {
          // Auto-enable performance mode on low battery
          await setPerformanceMode(true);
        }
      }
    });
  }

  @override
  void dispose() {
    _batteryStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final perfValue = await _storage.read(key: 'performance_mode');
    final compValue = await _storage.read(key: 'compress_media');
    final autoBackupValue = await _storage.read(key: 'auto_backup');
    final storageModeStr = await _storage.read(key: 'storage_mode');
    
    StorageMode parsedMode = StorageMode.smart;
    if (storageModeStr == 'device') parsedMode = StorageMode.device;
    if (storageModeStr == 'cloud') parsedMode = StorageMode.cloud;

    state = state.copyWith(
      performanceMode: perfValue == 'true',
      compressMedia: compValue == null || compValue == 'true', // Default is true
      autoBackup: autoBackupValue == 'true', // Default is false
      storageMode: parsedMode,
    );
  }

  Future<void> togglePerformanceMode() async {
    await setPerformanceMode(!state.performanceMode);
  }

  Future<void> setPerformanceMode(bool value) async {
    state = state.copyWith(performanceMode: value);
    await _storage.write(key: 'performance_mode', value: value.toString());
  }

  Future<void> toggleCompressMedia() async {
    final newValue = !state.compressMedia;
    state = state.copyWith(compressMedia: newValue);
    await _storage.write(key: 'compress_media', value: newValue.toString());
  }

  Future<void> toggleAutoBackup(bool value) async {
    state = state.copyWith(autoBackup: value);
    await _storage.write(key: 'auto_backup', value: value.toString());
  }

  Future<void> setStorageMode(StorageMode mode) async {
    state = state.copyWith(storageMode: mode);
    await _storage.write(key: 'storage_mode', value: mode.name);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
