// lib/core/hermes_engine/buffer/countdown_timer.dart

import 'dart:async';

/// A reusable countdown timer that ticks every second
/// and notifies listeners when ticking and upon completion.
class CountdownTimer {
  Timer? _timer;
  int _remainingSeconds = 0;

  /// Callback for each tick with seconds remaining.
  void Function(int secondsRemaining)? onTick;

  /// Callback when countdown completes.
  void Function()? onComplete;

  /// Whether the countdown is currently running.
  bool get isRunning => _timer?.isActive ?? false;

  /// Seconds still remaining.
  int get remainingSeconds => _remainingSeconds;

  /// Starts the countdown from [durationInSeconds].
  void start(int durationInSeconds) {
    _cancel();
    _remainingSeconds = durationInSeconds;

    // Trigger an immediate tick for UI to show start value
    onTick?.call(_remainingSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      onTick?.call(_remainingSeconds);

      if (_remainingSeconds <= 0) {
        _cancel();
        onComplete?.call();
      }
    });
  }

  /// Stops and resets the countdown without firing callbacks.
  void stop() => _cancel();

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 0;
  }
}
