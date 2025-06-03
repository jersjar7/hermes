// lib/core/services/speech_to_text/speech_to_text_service_impl.dart

import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_to_text_service.dart';
import 'speech_result.dart';
import 'continuous_speech_channel.dart';

/// Enhanced STT service that uses platform-specific continuous recognition
/// iOS & Android: True continuous recognition via custom platform channels
/// Fallback: Uses regular speech_to_text plugin with restart logic
class SpeechToTextServiceImpl implements ISpeechToTextService {
  // Platform-specific continuous speech
  ContinuousSpeechChannel? _continuousChannel;
  bool _useContinuousChannel = false;

  // Fallback regular STT (for platforms without continuous support)
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Session state
  bool _isAvailable = false;
  bool _isListening = false;
  String _locale = 'en-US';

  // Session callbacks
  void Function(SpeechResult)? _onResult;
  void Function(Exception)? _onError;

  @override
  Future<bool> initialize() async {
    print('🎙️ [STTService] Initializing enhanced speech-to-text service...');

    // Try to initialize continuous speech channel first
    await _initializeContinuousChannel();

    // Initialize fallback regular STT
    await _initializeFallbackSTT();

    final available = _useContinuousChannel || _isAvailable;

    if (_useContinuousChannel) {
      print('✅ [STTService] Using CONTINUOUS speech recognition');
    } else if (_isAvailable) {
      print('⚠️ [STTService] Using REGULAR speech recognition (with restarts)');
    } else {
      print('❌ [STTService] Speech recognition not available');
    }

    return available;
  }

  Future<void> _initializeContinuousChannel() async {
    try {
      _continuousChannel = ContinuousSpeechChannel.instance;

      // Check if continuous channel is available
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

    _onResult = onResult;
    _onError = onError;

    if (_useContinuousChannel) {
      await _startContinuousListening();
    } else {
      await _startFallbackListening();
    }
  }

  /// Start listening using continuous speech channel (iOS/Android optimized)
  Future<void> _startContinuousListening() async {
    print(
      '🎤 [STTService] Starting CONTINUOUS listening with locale: $_locale',
    );

    try {
      await _continuousChannel!.startContinuousListening(
        locale: _locale,
        onResult: (result) {
          print(
            '📝 [STTService-Continuous] Result: "${result.transcript}" (final: ${result.isFinal})',
          );
          _onResult?.call(result);
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

  /// Start listening using fallback STT with restart logic
  Future<void> _startFallbackListening() async {
    print('🎤 [STTService] Starting FALLBACK listening with locale: $_locale');

    try {
      await _speech.listen(
        localeId: _locale,
        onResult: _handleFallbackResult,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );

      _isListening = true;
      print('✅ [STTService] Fallback listening started');
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

  // Fallback STT handlers (for when continuous channel not available)
  void _handleFallbackStatus(String status) {
    print('📊 [STTService-Fallback] Status: $status');

    // Auto-restart logic for fallback mode
    if (status == 'notListening' && _isListening && _onResult != null) {
      _scheduleRestart();
    }
  }

  void _handleFallbackError(dynamic error) {
    print('❌ [STTService-Fallback] Error: $error');

    if (_onError != null) {
      _onError!(Exception('Speech recognition error: $error'));
    }

    // Try to restart after error
    if (_isListening) {
      _scheduleRestart();
    }
  }

  void _handleFallbackResult(stt.SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    if (transcript.isNotEmpty && _onResult != null) {
      final speechResult = SpeechResult(
        transcript: transcript,
        isFinal: result.finalResult,
        timestamp: DateTime.now(),
        locale: _locale,
      );

      print(
        '📝 [STTService-Fallback] Result: "$transcript" (final: ${result.finalResult})',
      );
      _onResult!(speechResult);
    }

    // Restart after final result for continuous experience
    if (result.finalResult && _isListening) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_isListening || _onResult == null) return;

    print('🔄 [STTService-Fallback] Scheduling restart...');

    // Use platform-appropriate delay
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
      // Return common locales for continuous channel
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
