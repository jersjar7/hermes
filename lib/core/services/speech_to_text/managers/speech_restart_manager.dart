// lib/core/services/speech_to_text/managers/speech_restart_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:hermes/core/services/logger/logger_service.dart';

/// Manages restart timing and delays for speech recognition.
/// Handles platform-specific delays and prevents restart loops.
class SpeechRestartManager {
  final ILoggerService _logger;

  Timer? _restartTimer;
  bool _isRestarting = false;
  DateTime? _lastStopTime;

  // Platform-specific delays
  static const Duration _androidMinRestartDelay = Duration(milliseconds: 1200);
  static const Duration _iosRestartDelay = Duration(milliseconds: 400);
  static const Duration _androidStopWait = Duration(milliseconds: 800);
  static const Duration _iosStopWait = Duration(milliseconds: 300);

  SpeechRestartManager(this._logger);

  /// Whether a restart is currently scheduled
  bool get isRestarting => _isRestarting;

  /// Waits for the appropriate delay before starting speech recognition
  Future<void> waitForNextStart() async {
    if (!Platform.isAndroid || _lastStopTime == null) {
      return; // No delay needed for iOS or first start
    }

    final timeSinceStop = DateTime.now().difference(_lastStopTime!);
    final minDelay = _androidMinRestartDelay;

    if (timeSinceStop < minDelay) {
      final remainingDelay = minDelay - timeSinceStop;
      print(
        '⏳ [RestartManager] Android: Waiting ${remainingDelay.inMilliseconds}ms before restart',
      );
      await Future.delayed(remainingDelay);
    }
  }

  /// Waits for the appropriate delay after stopping speech recognition
  Future<void> waitAfterStop() async {
    _lastStopTime = DateTime.now();

    final delay = Platform.isAndroid ? _androidStopWait : _iosStopWait;
    print('⏳ [RestartManager] Waiting ${delay.inMilliseconds}ms after stop');
    await Future.delayed(delay);
  }

  /// Schedules a restart with the given delay
  void scheduleRestart({
    Duration? customDelay,
    required Future<void> Function() onRestart,
  }) {
    // Cancel existing restart if any
    if (_isRestarting) {
      print(
        '⚠️ [RestartManager] Restart already scheduled, cancelling and rescheduling...',
      );
      _restartTimer?.cancel();
    }

    _isRestarting = true;

    // Calculate delay
    final delay = customDelay ?? _getDefaultRestartDelay();

    print(
      '🔄 [RestartManager] Scheduling restart in ${delay.inMilliseconds}ms',
    );

    _restartTimer = Timer(delay, () async {
      print('🔄 [RestartManager] Executing scheduled restart');

      try {
        await onRestart();
      } catch (e) {
        print('❌ [RestartManager] Restart failed: $e');
        _logger.logError('Restart failed', error: e, context: 'RestartManager');
      } finally {
        _isRestarting = false;
      }
    });
  }

  /// Cancels any pending restart
  void cancelRestart() {
    if (_isRestarting) {
      print('❌ [RestartManager] Cancelling restart');
      _restartTimer?.cancel();
      _restartTimer = null;
      _isRestarting = false;
    }
  }

  /// Gets the default restart delay for the current platform
  Duration _getDefaultRestartDelay() {
    return Platform.isAndroid ? _androidMinRestartDelay : _iosRestartDelay;
  }

  /// Gets a delay based on the number of consecutive errors
  Duration getErrorBackoffDelay(int consecutiveErrors) {
    // Exponential backoff: 2s, 4s, 6s, 8s, 10s (max)
    final seconds = (consecutiveErrors * 2).clamp(2, 10);
    return Duration(seconds: seconds);
  }

  /// Gets a delay for specific error types
  Duration getErrorTypeDelay(String errorType) {
    switch (errorType) {
      case 'error_busy':
        return Duration(seconds: 3); // Longer delay for busy errors
      case 'error_speech_timeout':
        return Duration(seconds: 2); // Medium delay for timeouts
      case 'error_no_match':
        return Platform.isAndroid
            ? _androidMinRestartDelay
            : Duration(milliseconds: 800);
      case 'error_audio':
        return Duration(seconds: 1);
      case 'error_network':
        return Duration(seconds: 3);
      default:
        return Duration(milliseconds: 1500); // Default delay
    }
  }

  /// Gets delay after a final result is processed
  Duration getFinalResultDelay() {
    return Duration(
      milliseconds: 1500,
    ); // Allow time for user to continue speaking
  }

  /// Gets restart manager status for debugging
  String getStatus() {
    return 'RestartManager(restarting: $_isRestarting, '
        'lastStop: ${_lastStopTime?.millisecondsSinceEpoch})';
  }

  void dispose() {
    print('🗑️ [RestartManager] Disposing');
    cancelRestart();
  }
}
