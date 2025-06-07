// lib/core/services/speech_to_text/speech_to_text_service_impl.dart
// FIXED: Removed auto-restart on final results for continuous 15-second processing

import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_to_text_service.dart';
import 'speech_result.dart';
import 'continuous_speech_channel.dart';

/// FIXED: STT service for 15-second timer processing pattern
/// Removed auto-restart on final results to enable continuous accumulation
class SpeechToTextServiceImpl implements ISpeechToTextService {
  // Platform-specific continuous speech
  ContinuousSpeechChannel? _continuousChannel;
  bool _useContinuousChannel = false;

  // Fallback regular STT
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Session state
  bool _isAvailable = false;
  bool _isListening = false;
  String _locale = 'en-US';

  // SIMPLIFIED: Only one callback for partial results
  void Function(SpeechResult)? _onResult;
  void Function(Exception)? _onError;

  @override
  Future<bool> initialize() async {
    print('🎙️ [STTService] Initializing FIXED speech-to-text service...');

    await _initializeContinuousChannel();
    await _initializeFallbackSTT();

    final available = _useContinuousChannel || _isAvailable;

    if (_useContinuousChannel) {
      print('✅ [STTService] Using continuous speech recognition');
    } else if (_isAvailable) {
      print('✅ [STTService] Using fallback STT (15-second timer mode)');
    } else {
      print('❌ [STTService] Speech recognition not available');
    }

    return available;
  }

  Future<void> _initializeContinuousChannel() async {
    try {
      _continuousChannel = ContinuousSpeechChannel.instance;

      final isAvailable = await _continuousChannel!.isAvailable;

      if (isAvailable) {
        final initialized = await _continuousChannel!.initialize();
        _useContinuousChannel = initialized;

        if (_useContinuousChannel) {
          print(
            '🚀 [STTService] Continuous speech channel initialized successfully',
          );
        } else {
          print(
            '⚠️ [STTService] Continuous speech channel available but initialization failed',
          );
        }
      } else {
        print(
          'ℹ️ [STTService] Continuous speech not available on this platform',
        );
      }
    } catch (e) {
      print('⚠️ [STTService] Continuous speech channel error: $e');
      _useContinuousChannel = false;
    }
  }

  Future<void> _initializeFallbackSTT() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: _handleFallbackStatus,
        onError: _handleFallbackError,
        debugLogging: false,
      );

      if (_isAvailable) {
        print('✅ [STTService] Fallback STT initialized');
      }
    } catch (e) {
      print('❌ [STTService] Fallback STT initialization failed: $e');
      _isAvailable = false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(SpeechResult) onResult,
    required void Function(Exception) onError,
  }) async {
    if (!(_useContinuousChannel || _isAvailable)) {
      final msg = 'Speech recognition not available';
      print('❌ [STTService] $msg');
      onError(Exception(msg));
      return;
    }

    print('🎤 [STTService] Starting FIXED listening (15-second timer mode)...');

    _onResult = onResult;
    _onError = onError;

    if (_useContinuousChannel) {
      await _startContinuousListening();
    } else {
      await _startFallbackListening();
    }
  }

  /// Start listening using continuous speech channel (only partial results)
  Future<void> _startContinuousListening() async {
    print(
      '🎤 [STTService] Starting continuous listening with locale: $_locale',
    );

    try {
      await _continuousChannel!.startContinuousListening(
        locale: _locale,
        onResult: (result) {
          // ALL results are treated as partials for buffer processing
          print(
            '📝 [STTService-Continuous] Partial result: "${result.transcript}"',
          );

          final partialResult = SpeechResult(
            transcript: result.transcript,
            isFinal: false, // Always false - buffer will decide when to process
            timestamp: DateTime.now(),
            locale: _locale,
          );

          _onResult?.call(partialResult);
        },
        onError: (error) {
          print('❌ [STTService-Continuous] Error: $error');
          _onError?.call(Exception(error));
        },
      );

      _isListening = true;
      print('✅ [STTService] Continuous listening started successfully');
    } catch (e) {
      print('❌ [STTService] Continuous listening failed: $e');
      _onError?.call(Exception('Failed to start continuous listening: $e'));
    }
  }

  /// 🎯 FIXED: Start listening using fallback STT for 15-second timer processing
  /// Increased duration and removed auto-restart on final results
  Future<void> _startFallbackListening() async {
    print(
      '🎤 [STTService] Starting FIXED fallback listening with locale: $_locale',
    );

    try {
      await _speech.listen(
        localeId: _locale,
        onResult: _handleFallbackResult,
        cancelOnError: false,
        partialResults: true,
        // 🎯 FIXED: Much longer duration to support 15-second timer
        listenFor: const Duration(
          minutes: 10,
        ), // Was 30 seconds, now 10 minutes
        // 🎯 FIXED: Longer pause to prevent premature stops
        pauseFor: const Duration(seconds: 10), // Was 3 seconds, now 10 seconds
      );

      _isListening = true;
      print(
        '✅ [STTService] FIXED fallback listening started (10min duration, 10s pause)',
      );
    } catch (e) {
      print('❌ [STTService] Fallback listening failed: $e');
      _onError?.call(Exception('Failed to start listening: $e'));
    }
  }

  @override
  Future<void> stopListening() async {
    print('🛑 [STTService] Stopping listening...');

    _isListening = false;

    if (_useContinuousChannel) {
      await _stopContinuousListening();
    } else {
      await _stopFallbackListening();
    }

    _onResult = null;
    _onError = null;

    print('✅ [STTService] Listening stopped');
  }

  Future<void> _stopContinuousListening() async {
    try {
      await _continuousChannel?.stopContinuousListening();
      print('✅ [STTService] Continuous listening stopped');
    } catch (e) {
      print('⚠️ [STTService] Error stopping continuous listening: $e');
    }
  }

  Future<void> _stopFallbackListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
      print('✅ [STTService] Fallback listening stopped');
    } catch (e) {
      print('⚠️ [STTService] Error stopping fallback listening: $e');
    }
  }

  @override
  Future<void> cancel() async {
    print('❌ [STTService] Cancelling listening...');

    _isListening = false;
    _onResult = null;
    _onError = null;

    if (_useContinuousChannel) {
      await _continuousChannel?.stopContinuousListening();
    } else {
      await _speech.cancel();
    }

    print('✅ [STTService] Listening cancelled');
  }

  // 🎯 FIXED: Fallback STT handlers for 15-second timer pattern
  void _handleFallbackStatus(String status) {
    print('📊 [STTService-Fallback] Status: $status');

    // 🎯 FIXED: Only restart on actual stops, not normal processing
    if (status == 'notListening' && _isListening && _onResult != null) {
      // Only restart if we're supposed to be listening but aren't
      print('⚠️ [STTService-Fallback] Unexpected stop detected, restarting...');
      _scheduleRestart();
    }
  }

  void _handleFallbackError(dynamic error) {
    print('❌ [STTService-Fallback] Error: $error');

    if (_onError != null) {
      _onError!(Exception('Speech recognition error: $error'));
    }

    if (_isListening) {
      _scheduleRestart();
    }
  }

  /// 🎯 FIXED: Handle fallback results without auto-restart
  void _handleFallbackResult(stt.SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    if (transcript.isNotEmpty && _onResult != null) {
      // SIMPLIFIED: All results are partials, even iOS "final" results
      // Buffer processing will decide when to actually process sentences
      final speechResult = SpeechResult(
        transcript: transcript,
        isFinal: false, // Always false - buffer decides processing timing
        timestamp: DateTime.now(),
        locale: _locale,
      );

      print(
        '📝 [STTService-Fallback] Result: "$transcript" (treating as partial)',
      );
      _onResult!(speechResult);
    }

    // 🎯 FIXED: REMOVED AUTO-RESTART ON FINAL RESULTS
    // This was the cause of the fragmentation! iOS STT naturally returns
    // "final" results every few seconds, but we want continuous accumulation
    // for the 15-second timer pattern.

    // OLD CODE (REMOVED):
    // if (result.finalResult && _isListening) {
    //   _scheduleRestart();
    // }

    // NEW: Only log final results, don't restart
    if (result.finalResult) {
      print(
        '📋 [STTService-Fallback] Received final result, continuing to accumulate...',
      );
    }
  }

  /// 🎯 FIXED: Only restart on actual errors/stops, not final results
  void _scheduleRestart() {
    if (!_isListening || _onResult == null) return;

    print('🔄 [STTService-Fallback] Scheduling restart due to error/stop...');

    final delay =
        Platform.isAndroid
            ? const Duration(milliseconds: 1200)
            : const Duration(milliseconds: 400);

    Timer(delay, () async {
      if (_isListening && _onResult != null) {
        print('🔄 [STTService-Fallback] Restarting...');
        try {
          await _startFallbackListening();
        } catch (e) {
          print('❌ [STTService-Fallback] Restart failed: $e');
        }
      }
    });
  }

  @override
  bool get isAvailable => _useContinuousChannel || _isAvailable;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async => isAvailable;

  @override
  Future<void> setLocale(String localeId) async {
    print('🌍 [STTService] Setting locale to: $localeId');
    _locale = localeId;
  }

  @override
  Future<List<LocaleName>> getSupportedLocales() async {
    if (_useContinuousChannel) {
      return [
        LocaleName(localeId: 'en-US', name: 'English (US)'),
        LocaleName(localeId: 'es-ES', name: 'Spanish (Spain)'),
        LocaleName(localeId: 'fr-FR', name: 'French (France)'),
        LocaleName(localeId: 'de-DE', name: 'German (Germany)'),
        LocaleName(localeId: 'it-IT', name: 'Italian (Italy)'),
        LocaleName(localeId: 'pt-BR', name: 'Portuguese (Brazil)'),
        LocaleName(localeId: 'ru-RU', name: 'Russian (Russia)'),
        LocaleName(localeId: 'ja-JP', name: 'Japanese (Japan)'),
        LocaleName(localeId: 'ko-KR', name: 'Korean (Korea)'),
        LocaleName(localeId: 'zh-CN', name: 'Chinese (China)'),
      ];
    } else {
      try {
        final locales = await _speech.locales();
        return locales
            .map((e) => LocaleName(localeId: e.localeId, name: e.name))
            .toList();
      } catch (e) {
        print('❌ [STTService] Failed to get supported locales: $e');
        return [];
      }
    }
  }

  @override
  void dispose() {
    print('🗑️ [STTService] Disposing STT service...');

    _isListening = false;
    _onResult = null;
    _onError = null;

    _continuousChannel?.dispose();

    print('✅ [STTService] STT service disposed');
  }
}
