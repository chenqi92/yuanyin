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

  Future<String> getPlayMode() async => (await get<String>('playMode')) ?? 'loop';
  Future<void> setPlayMode(String m) => set('playMode', m);

  Future<String> getEngine() async => (await get<String>('engine')) ?? 'just_audio';
  Future<void> setEngine(String e) => set('engine', e);

  Future<double> getCrossfadeDuration() async => (await get<double>('crossfade')) ?? 0;
  Future<void> setCrossfadeDuration(double d) => set('crossfade', d);

  Future<String> getThemeMode() async => (await get<String>('themeMode')) ?? 'system';
  Future<void> setThemeMode(String m) => set('themeMode', m);

  Future<bool> getGaplessPlayback() async => (await get<bool>('gapless')) ?? true;
  Future<void> setGaplessPlayback(bool v) => set('gapless', v);

  Future<bool> getShowLyrics() async => (await get<bool>('showLyrics')) ?? true;
  Future<void> setShowLyrics(bool v) => set('showLyrics', v);
}

/// 应用设置状态
class AppSettings {
  final double volume;
  final String playMode;        // 'loop', 'repeat_one', 'shuffle'
  final String engine;          // 'just_audio', 'media_kit'
  final double crossfadeDuration;
  final String themeMode;       // 'light', 'dark', 'system'
  final bool gaplessPlayback;
  final bool showLyrics;

  const AppSettings({
    this.volume = 1.0,
    this.playMode = 'loop',
    this.engine = 'just_audio',
    this.crossfadeDuration = 0,
    this.themeMode = 'system',
    this.gaplessPlayback = true,
    this.showLyrics = true,
  });

  AppSettings copyWith({
    double? volume,
    String? playMode,
    String? engine,
    double? crossfadeDuration,
    String? themeMode,
    bool? gaplessPlayback,
    bool? showLyrics,
  }) {
    return AppSettings(
      volume: volume ?? this.volume,
      playMode: playMode ?? this.playMode,
      engine: engine ?? this.engine,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      themeMode: themeMode ?? this.themeMode,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      showLyrics: showLyrics ?? this.showLyrics,
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
      playMode: await _service.getPlayMode(),
      engine: await _service.getEngine(),
      crossfadeDuration: await _service.getCrossfadeDuration(),
      themeMode: await _service.getThemeMode(),
      gaplessPlayback: await _service.getGaplessPlayback(),
      showLyrics: await _service.getShowLyrics(),
    );
  }

  Future<void> setVolume(double v) async {
    await _service.setVolume(v);
    state = state.copyWith(volume: v);
  }

  Future<void> setPlayMode(String mode) async {
    await _service.setPlayMode(mode);
    state = state.copyWith(playMode: mode);
  }

  Future<void> setEngine(String engine) async {
    await _service.setEngine(engine);
    state = state.copyWith(engine: engine);
  }

  Future<void> setCrossfade(double duration) async {
    await _service.setCrossfadeDuration(duration);
    state = state.copyWith(crossfadeDuration: duration);
  }

  Future<void> setThemeMode(String mode) async {
    await _service.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setGapless(bool v) async {
    await _service.setGaplessPlayback(v);
    state = state.copyWith(gaplessPlayback: v);
  }

  Future<void> setShowLyrics(bool v) async {
    await _service.setShowLyrics(v);
    state = state.copyWith(showLyrics: v);
  }
}

/// Providers
final settingsServiceProvider = Provider((ref) => SettingsService());

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsServiceProvider));
});
