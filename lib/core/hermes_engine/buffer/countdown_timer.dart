import 'dart:async';

/// A reusable countdown timer that ticks every second
/// and notifies listeners on each tick and when finished.
class CountdownTimer {
  Timer? _timer;
  int _remainingSeconds = 0;

  /// Called every second with the updated time.
  void Function(int secondsRemaining)? onTick;

  /// Called once when countdown completes.
  void Function()? onComplete;

  bool get isRunning => _timer?.isActive ?? false;
  int get remainingSeconds => _remainingSeconds;

  /// Starts the countdown for the given duration.
  void start(int durationInSeconds) {
    _cancel(); // Clear any previous timer
    _remainingSeconds = durationInSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;

      if (onTick != null) onTick!(_remainingSeconds);

      if (_remainingSeconds <= 0) {
        _cancel();
        if (onComplete != null) onComplete!();
      }
    });
  }

  /// Stops and resets the countdown.
  void stop() => _cancel();

  /// Cancels the timer without triggering any callbacks.
  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 0;
  }
}
