// lib/core/services/speech_to_text/continuous_speech_channel.dart
// STEP 1: Enhanced platform channel for pattern-confirmed results

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'speech_result.dart';

/// Enhanced platform channel for truly continuous speech recognition
/// Now handles pattern-confirmed complete sentences separately
class ContinuousSpeechChannel {
  static const _methodChannel = MethodChannel('hermes/continuous_speech');
  static const _eventChannel = EventChannel('hermes/continuous_speech/events');

  static ContinuousSpeechChannel? _instance;

  StreamSubscription<dynamic>? _eventSubscription;
  StreamController<SpeechResult>? _resultController;

  // 🆕 NEW: Separate callback for pattern-confirmed complete sentences
  void Function(SpeechResult)? _onPatternConfirmedSentence;

  bool _isListening = false;
  bool _isAvailable = false;

  ContinuousSpeechChannel._();

  static ContinuousSpeechChannel get instance {
    _instance ??= ContinuousSpeechChannel._();
    return _instance!;
  }

  Future<bool> get isAvailable async {
    try {
      _isAvailable = await _methodChannel.invokeMethod('isAvailable') ?? false;

      if (Platform.isIOS) {
        print('📱 [ContinuousSpeech-iOS] Availability check: $_isAvailable');
      } else if (Platform.isAndroid) {
        print(
          '🤖 [ContinuousSpeech-Android] Availability check: $_isAvailable',
        );
      } else {
        print(
          '🚫 [ContinuousSpeech] Platform ${Platform.operatingSystem} not supported',
        );
        return false;
      }

      return _isAvailable;
    } catch (e) {
      print('❌ [ContinuousSpeech] Availability check failed: $e');
      return false;
    }
  }

  Future<bool> initialize() async {
    print('🎙️ [ContinuousSpeech] Initializing...');

    try {
      final result = await _methodChannel.invokeMethod('initialize') ?? false;

      if (Platform.isIOS) {
        print('📱 [ContinuousSpeech-iOS] Initialize result: $result');
      } else if (Platform.isAndroid) {
        print('🤖 [ContinuousSpeech-Android] Initialize result: $result');
      }

      return result;
    } catch (e) {
      print('❌ [ContinuousSpeech] Initialize failed: $e');
      return false;
    }
  }

  /// 🆕 ENHANCED: Start listening with separate callbacks for partial and confirmed results
  Future<void> startContinuousListening({
    required String locale,
    required void Function(SpeechResult) onResult,
    required void Function(String) onError,
    void Function(SpeechResult)? onPatternConfirmedSentence, // 🆕 NEW callback
  }) async {
    if (_isListening) {
      print('⚠️ [ContinuousSpeech] Already listening, ignoring start request');
      return;
    }

    print(
      Platform.isIOS
          ? '🎤 [ContinuousSpeech-iOS] Starting PATTERN-BASED continuous listening with locale: $locale'
          : '🎤 [ContinuousSpeech-Android] Starting optimized listening with locale: $locale',
    );

    // Store the pattern-confirmed callback
    _onPatternConfirmedSentence = onPatternConfirmedSentence;

    try {
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

      final params = <String, dynamic>{
        'locale': locale,
        'partialResults': true,
      };

      if (Platform.isIOS) {
        params['onDeviceRecognition'] = true;
      }

      await _methodChannel.invokeMethod('startContinuousRecognition', params);

      _isListening = true;
      print(
        Platform.isIOS
            ? '✅ [ContinuousSpeech-iOS] Pattern-based continuous recognition started'
            : '✅ [ContinuousSpeech-Android] Optimized recognition started (50ms gaps)',
      );
    } catch (e) {
      print('❌ [ContinuousSpeech] Start failed: $e');
      await _cleanup();
      onError('Failed to start continuous recognition: $e');
    }
  }

  Future<void> stopContinuousListening() async {
    if (!_isListening) {
      print('⚠️ [ContinuousSpeech] Not listening, ignoring stop request');
      return;
    }

    final platformMsg =
        Platform.isIOS
            ? '🛑 [ContinuousSpeech-iOS] Stopping pattern-based listening...'
            : '🛑 [ContinuousSpeech-Android] Stopping optimized listening...';
    print(platformMsg);

    try {
      await _methodChannel.invokeMethod('stopContinuousRecognition');

      final successMsg =
          Platform.isIOS
              ? '✅ [ContinuousSpeech-iOS] Pattern-based recognition stopped'
              : '✅ [ContinuousSpeech-Android] Optimized recognition stopped';
      print(successMsg);
    } catch (e) {
      print('❌ [ContinuousSpeech] Stop failed: $e');
    } finally {
      await _cleanup();
    }
  }

  /// 🆕 ENHANCED: Handle different types of speech events
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
      case 'pattern_confirmed': // 🆕 NEW: Handle pattern-confirmed complete sentences
        _handlePatternConfirmedEvent(eventMap);
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
      final platformTag = Platform.isIOS ? 'iOS' : 'Android';
      print(
        '📝 [ContinuousSpeech-$platformTag] Partial result: "$transcript" (final: $isFinal, confidence: $confidence)',
      );

      final result = SpeechResult(
        transcript: transcript,
        isFinal: false, // Always false for partial results now
        timestamp: DateTime.now(),
        locale: event['locale'] as String? ?? 'en-US',
      );

      onResult(result);
    }
  }

  /// 🆕 NEW: Handle pattern-confirmed complete sentences
  void _handlePatternConfirmedEvent(Map<String, dynamic> event) {
    final transcript = event['transcript'] as String? ?? '';
    final reason = event['reason'] as String? ?? 'pattern';

    if (transcript.isNotEmpty && _onPatternConfirmedSentence != null) {
      final platformTag = Platform.isIOS ? 'iOS' : 'Android';
      print(
        '🎯 [ContinuousSpeech-$platformTag] ✅ PATTERN CONFIRMED: "$transcript" (reason: $reason)',
      );

      final result = SpeechResult(
        transcript: transcript,
        isFinal: true, // This is truly final - confirmed by pattern detector
        timestamp: DateTime.now(),
        locale: event['locale'] as String? ?? 'en-US',
      );

      _onPatternConfirmedSentence!(result);
    }
  }

  void _handleErrorEvent(
    Map<String, dynamic> event,
    void Function(String) onError,
  ) {
    final errorMessage = event['message'] as String? ?? 'Unknown error';
    final platformTag = Platform.isIOS ? 'iOS' : 'Android';
    print('❌ [ContinuousSpeech-$platformTag] Error event: $errorMessage');
    onError(errorMessage);
  }

  void _handleStatusEvent(Map<String, dynamic> event) {
    final status = event['status'] as String? ?? 'unknown';
    final platformTag = Platform.isIOS ? 'iOS' : 'Android';
    print('📊 [ContinuousSpeech-$platformTag] Status: $status');

    if (status == 'stopped') {
      _isListening = false;
    }
  }

  Future<void> _cleanup() async {
    _isListening = false;
    _onPatternConfirmedSentence = null;

    await _eventSubscription?.cancel();
    _eventSubscription = null;

    await _resultController?.close();
    _resultController = null;

    print('🧹 [ContinuousSpeech] Cleanup completed');
  }

  bool get isListening => _isListening;

  Future<void> dispose() async {
    print('🗑️ [ContinuousSpeech] Disposing...');
    await stopContinuousListening();
    await _cleanup();
  }
}
