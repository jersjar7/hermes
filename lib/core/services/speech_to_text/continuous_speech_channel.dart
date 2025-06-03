// lib/core/services/speech_to_text/continuous_speech_channel.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'speech_result.dart';

/// Platform channel for truly continuous speech recognition
/// Bypasses the speech_to_text plugin's restart delays on iOS
class ContinuousSpeechChannel {
  static const _methodChannel = MethodChannel('hermes/continuous_speech');
  static const _eventChannel = EventChannel('hermes/continuous_speech/events');

  static ContinuousSpeechChannel? _instance;

  StreamSubscription<dynamic>? _eventSubscription;
  StreamController<SpeechResult>? _resultController;

  bool _isListening = false;
  bool _isAvailable = false;

  // Private constructor for singleton
  ContinuousSpeechChannel._();

  /// Get singleton instance
  static ContinuousSpeechChannel get instance {
    _instance ??= ContinuousSpeechChannel._();
    return _instance!;
  }

  /// Check if continuous speech recognition is available on this platform
  Future<bool> get isAvailable async {
    if (!Platform.isIOS) {
      print('🚫 [ContinuousSpeech] Only iOS supported in Quick Start');
      return false;
    }

    try {
      _isAvailable = await _methodChannel.invokeMethod('isAvailable') ?? false;
      print('📱 [ContinuousSpeech] Availability check: $_isAvailable');
      return _isAvailable;
    } catch (e) {
      print('❌ [ContinuousSpeech] Availability check failed: $e');
      return false;
    }
  }

  /// MARK: Initialize the continuous speech recognition
  Future<bool> initialize() async {
    print('🎙️ [ContinuousSpeech] Initializing...');

    if (!Platform.isIOS) {
      print('🚫 [ContinuousSpeech] iOS only for Quick Start');
      return false;
    }

    try {
      final result = await _methodChannel.invokeMethod('initialize') ?? false;
      print('📱 [ContinuousSpeech] Initialize result: $result');
      return result;
    } catch (e) {
      print('❌ [ContinuousSpeech] Initialize failed: $e');
      return false;
    }
  }

  /// Start continuous speech recognition with truly no gaps
  Future<void> startContinuousListening({
    required String locale,
    required void Function(SpeechResult) onResult,
    required void Function(String) onError,
  }) async {
    if (_isListening) {
      print('⚠️ [ContinuousSpeech] Already listening, ignoring start request');
      return;
    }

    print(
      '🎤 [ContinuousSpeech] Starting continuous listening with locale: $locale',
    );

    try {
      // Set up event stream for results
      _resultController = StreamController<SpeechResult>.broadcast();

      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          _handleSpeechEvent(event, onResult, onError);
        },
        onError: (dynamic error) {
          print('❌ [ContinuousSpeech] Event stream error: $error');
          onError('Event stream error: $error');
        },
      );

      // Start recognition on native side
      await _methodChannel.invokeMethod('startContinuousRecognition', {
        'locale': locale,
        'onDeviceRecognition': true,
        'partialResults': true,
      });

      _isListening = true;
      print('✅ [ContinuousSpeech] Continuous recognition started');
    } catch (e) {
      print('❌ [ContinuousSpeech] Start failed: $e');
      await _cleanup();
      onError('Failed to start continuous recognition: $e');
    }
  }

  /// Stop continuous speech recognition
  Future<void> stopContinuousListening() async {
    if (!_isListening) {
      print('⚠️ [ContinuousSpeech] Not listening, ignoring stop request');
      return;
    }

    print('🛑 [ContinuousSpeech] Stopping continuous listening...');

    try {
      await _methodChannel.invokeMethod('stopContinuousRecognition');
      print('✅ [ContinuousSpeech] Native recognition stopped');
    } catch (e) {
      print('❌ [ContinuousSpeech] Stop failed: $e');
    } finally {
      await _cleanup();
    }
  }

  /// Handle speech events from native platform
  void _handleSpeechEvent(
    dynamic event,
    void Function(SpeechResult) onResult,
    void Function(String) onError,
  ) {
    if (event is! Map) {
      print('⚠️ [ContinuousSpeech] Invalid event format: $event');
      return;
    }

    final eventMap = Map<String, dynamic>.from(event);
    final type = eventMap['type'] as String?;

    switch (type) {
      case 'result':
        _handleResultEvent(eventMap, onResult);
        break;
      case 'error':
        _handleErrorEvent(eventMap, onError);
        break;
      case 'status':
        _handleStatusEvent(eventMap);
        break;
      default:
        print('⚠️ [ContinuousSpeech] Unknown event type: $type');
    }
  }

  void _handleResultEvent(
    Map<String, dynamic> event,
    void Function(SpeechResult) onResult,
  ) {
    final transcript = event['transcript'] as String? ?? '';
    final isFinal = event['isFinal'] as bool? ?? false;
    final confidence = event['confidence'] as double? ?? 1.0;

    if (transcript.isNotEmpty) {
      print(
        '📝 [ContinuousSpeech] Result: "$transcript" (final: $isFinal, confidence: $confidence)',
      );

      final result = SpeechResult(
        transcript: transcript,
        isFinal: isFinal,
        timestamp: DateTime.now(),
        locale: event['locale'] as String? ?? 'en-US',
      );

      onResult(result);
    }
  }

  void _handleErrorEvent(
    Map<String, dynamic> event,
    void Function(String) onError,
  ) {
    final errorMessage = event['message'] as String? ?? 'Unknown error';
    print('❌ [ContinuousSpeech] Error event: $errorMessage');
    onError(errorMessage);
  }

  void _handleStatusEvent(Map<String, dynamic> event) {
    final status = event['status'] as String? ?? 'unknown';
    print('📊 [ContinuousSpeech] Status: $status');

    if (status == 'stopped') {
      _isListening = false;
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    _isListening = false;

    await _eventSubscription?.cancel();
    _eventSubscription = null;

    await _resultController?.close();
    _resultController = null;

    print('🧹 [ContinuousSpeech] Cleanup completed');
  }

  /// Whether continuous recognition is currently active
  bool get isListening => _isListening;

  /// Dispose of the service (call on app shutdown)
  Future<void> dispose() async {
    print('🗑️ [ContinuousSpeech] Disposing...');
    await stopContinuousListening();
    await _cleanup();
  }
}
