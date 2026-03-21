import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../player/presentation/providers/player_provider.dart';

/// 定时关闭服务
///
/// 在指定时间后自动暂停播放。
class SleepTimerService {
  Timer? _timer;
  DateTime? _endTime;
  final void Function()? onFinished;

  SleepTimerService({this.onFinished});

  /// 启动定时器
  void start(Duration duration) {
    cancel();
    _endTime = DateTime.now().add(duration);
    _timer = Timer(duration, () {
      _endTime = null;
      onFinished?.call();
    });
  }

  /// 取消定时器
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _endTime = null;
  }

  /// 是否正在计时
  bool get isActive => _timer?.isActive ?? false;

  /// 剩余时间
  Duration get remaining {
    if (_endTime == null) return Duration.zero;
    final diff = _endTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void dispose() => cancel();
}

/// 定时关闭状态
class SleepTimerState {
  final bool isActive;
  final Duration remaining;
  final Duration? selectedDuration;

  const SleepTimerState({
    this.isActive = false,
    this.remaining = Duration.zero,
    this.selectedDuration,
  });

  SleepTimerState copyWith({bool? isActive, Duration? remaining, Duration? selectedDuration}) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      remaining: remaining ?? this.remaining,
      selectedDuration: selectedDuration ?? this.selectedDuration,
    );
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  final Ref _ref;
  SleepTimerService? _service;
  Timer? _ticker;

  SleepTimerNotifier(this._ref) : super(const SleepTimerState());

  void startTimer(Duration duration) {
    _service?.dispose();
    _service = SleepTimerService(onFinished: () {
      _ref.read(playerProvider.notifier).togglePlay();
      _ticker?.cancel();
      state = const SleepTimerState();
    });
    _service!.start(duration);
    state = SleepTimerState(isActive: true, remaining: duration, selectedDuration: duration);

    // 每秒更新剩余时间
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_service != null && _service!.isActive) {
        state = state.copyWith(remaining: _service!.remaining);
      }
    });
  }

  void cancelTimer() {
    _service?.cancel();
    _ticker?.cancel();
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _service?.dispose();
    _ticker?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier(ref);
});
