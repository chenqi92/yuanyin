import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import '../../../player/presentation/providers/player_provider.dart';
import 'music_audio_handler.dart';

final _log = Logger(printer: SimplePrinter());

/// 均衡器服务
///
/// 5 段均衡器 (60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz)
/// 存储预设和自定义频段增益值到 Hive
class EqualizerService {
  static const _boxName = 'equalizer';
  Box? _box;

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// 获取当前均衡器设置
  Future<EqualizerState> getState() async {
    final box = await _openBox;
    final enabled = box.get('enabled', defaultValue: false) as bool;
    final presetName = box.get('preset', defaultValue: '平坦') as String;
    final customGains = box.get('customGains');
    List<double> gains;
    if (customGains is List) {
      gains = customGains.cast<double>().toList();
    } else {
      gains = _presets[presetName] ?? _presets['平坦']!;
    }
    return EqualizerState(
      enabled: enabled,
      presetName: presetName,
      gains: gains,
    );
  }

  /// 保存均衡器设置
  Future<void> saveState(EqualizerState state) async {
    final box = await _openBox;
    await box.put('enabled', state.enabled);
    await box.put('preset', state.presetName);
    await box.put('customGains', state.gains);
  }

  /// 全部预设
  static Map<String, List<double>> get presets => _presets;
}

/// 均衡器预设
const Map<String, List<double>> _presets = {
  '平坦':     [0.0, 0.0, 0.0, 0.0, 0.0],
  '低音增强':  [5.0, 3.5, 0.0, 0.0, 1.0],
  '高音增强':  [0.0, 0.0, 1.0, 3.0, 5.0],
  '人声':     [-2.0, 0.0, 3.0, 3.5, 1.0],
  '摇滚':     [4.0, 2.0, -1.0, 2.0, 4.0],
  '流行':     [1.0, 3.0, 4.0, 2.0, -1.0],
  '古典':     [3.0, 1.5, 0.0, 1.5, 3.0],
  '爵士':     [3.0, 0.0, 1.5, 0.0, 3.0],
  '电子':     [4.0, 2.0, 0.0, 2.0, 4.5],
};

/// 频段定义
const List<String> eqBandLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

/// 均衡器状态
class EqualizerState {
  final bool enabled;
  final String presetName;
  final List<double> gains; // -12 to +12 dB each band

  const EqualizerState({
    this.enabled = false,
    this.presetName = '平坦',
    this.gains = const [0.0, 0.0, 0.0, 0.0, 0.0],
  });

  EqualizerState copyWith({bool? enabled, String? presetName, List<double>? gains}) {
    return EqualizerState(
      enabled: enabled ?? this.enabled,
      presetName: presetName ?? this.presetName,
      gains: gains ?? this.gains,
    );
  }
}

/// Notifier — 桥接 EQ 增益到播放引擎
class EqualizerNotifier extends StateNotifier<EqualizerState> {
  final EqualizerService _service;
  final Ref _ref;

  EqualizerNotifier(this._service, this._ref) : super(const EqualizerState()) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.getState();
    _applyToEngine();
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _service.saveState(state);
    _applyToEngine();
  }

  Future<void> setPreset(String name) async {
    final gains = _presets[name];
    if (gains != null) {
      state = state.copyWith(presetName: name, gains: List.from(gains));
      await _service.saveState(state);
      _applyToEngine();
    }
  }

  Future<void> setBandGain(int index, double gain) async {
    final gains = List<double>.from(state.gains);
    gains[index] = gain.clamp(-12.0, 12.0);
    state = state.copyWith(presetName: '自定义', gains: gains);
    await _service.saveState(state);
    _applyToEngine();
  }

  Future<void> resetAll() async {
    state = const EqualizerState();
    await _service.saveState(state);
    _applyToEngine();
  }

  /// 将 EQ 增益应用到音频引擎
  void _applyToEngine() {
    try {
      final handler = _ref.read(audioHandlerProvider);
      if (handler is MusicAudioHandler) {
        handler.setEqualizerGains(state.gains, state.enabled);
      }
    } catch (_) {
      // audioHandler 尚未初始化或不支持
    }
  }
}

/// Providers
final equalizerServiceProvider = Provider((ref) => EqualizerService());

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
  return EqualizerNotifier(ref.watch(equalizerServiceProvider), ref);
});
