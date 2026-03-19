import 'package:hive_ce/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置服务 — Hive 持久化
class SettingsService {
  static const _boxName = 'settings';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<T?> get<T>(String key) async {
    final box = await _openBox;
    return box.get(key) as T?;
  }

  Future<void> set<T>(String key, T value) async {
    final box = await _openBox;
    await box.put(key, value);
  }

  // ---- 快捷访问 ----

  Future<double> getVolume() async => (await get<double>('volume')) ?? 1.0;
  Future<void> setVolume(double v) => set('volume', v);

  Future<int> getPlayModeIndex() async => (await get<int>('playMode')) ?? 0;
  Future<void> setPlayModeIndex(int i) => set('playMode', i);

  Future<String> getEngine() async => (await get<String>('engine')) ?? 'justAudio';
  Future<void> setEngine(String e) => set('engine', e);

  Future<double> getCrossfadeDuration() async => (await get<double>('crossfade')) ?? 0;
  Future<void> setCrossfadeDuration(double d) => set('crossfade', d);
}

/// 应用设置状态
class AppSettings {
  final double volume;
  final int playModeIndex;
  final String engine;
  final double crossfadeDuration;

  const AppSettings({
    this.volume = 1.0,
    this.playModeIndex = 0,
    this.engine = 'justAudio',
    this.crossfadeDuration = 0,
  });

  AppSettings copyWith({
    double? volume,
    int? playModeIndex,
    String? engine,
    double? crossfadeDuration,
  }) {
    return AppSettings(
      volume: volume ?? this.volume,
      playModeIndex: playModeIndex ?? this.playModeIndex,
      engine: engine ?? this.engine,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
    );
  }
}

/// 设置 Notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = AppSettings(
      volume: await _service.getVolume(),
      playModeIndex: await _service.getPlayModeIndex(),
      engine: await _service.getEngine(),
      crossfadeDuration: await _service.getCrossfadeDuration(),
    );
  }

  Future<void> setVolume(double v) async {
    await _service.setVolume(v);
    state = state.copyWith(volume: v);
  }

  Future<void> setPlayMode(int index) async {
    await _service.setPlayModeIndex(index);
    state = state.copyWith(playModeIndex: index);
  }

  Future<void> setEngine(String engine) async {
    await _service.setEngine(engine);
    state = state.copyWith(engine: engine);
  }

  Future<void> setCrossfade(double duration) async {
    await _service.setCrossfadeDuration(duration);
    state = state.copyWith(crossfadeDuration: duration);
  }
}

/// Providers
final settingsServiceProvider = Provider((ref) => SettingsService());

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsServiceProvider));
});
