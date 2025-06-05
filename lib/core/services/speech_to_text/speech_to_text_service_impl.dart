// lib/core/services/speech_to_text/speech_to_text_service_impl.dart
// STEP 2: Enhanced STT service with pattern-confirmed support

import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_to_text_service.dart';
import 'speech_result.dart';
import 'continuous_speech_channel.dart';

/// Enhanced STT service that separates partial results from pattern-confirmed sentences
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

  // 🆕 NEW: Separate callbacks for partial and confirmed results
  void Function(SpeechResult)? _onPartialResult;
  void Function(SpeechResult)? _onConfirmedSentence;
  void Function(Exception)? _onError;

  @override
  Future<bool> initialize() async {
    print(
      '🎙️ [STTService] Initializing PATTERN-BASED speech-to-text service...',
    );

    await _initializeContinuousChannel();
    await _initializeFallbackSTT();

    final available = _useContinuousChannel || _isAvailable;

    if (_useContinuousChannel) {
      print('✅ [STTService] Using PATTERN-BASED continuous speech recognition');
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

      final isAvailable = await _continuousChannel!.isAvailable;

      if (isAvailable) {
        final initialized = await _continuousChannel!.initialize();
        _useContinuousChannel = initialized;

        if (_useContinuousChannel) {
          print(
            '🚀 [STTService] Pattern-based continuous speech channel initialized successfully',
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

    // 🎯 For backward compatibility: treat single callback as partial results only
    _onPartialResult = onResult;
    _onConfirmedSentence = null; // No confirmed callback in legacy mode
    _onError = onError;

    if (_useContinuousChannel) {
      await _startPatternBasedListening();
    } else {
      await _startFallbackListening();
    }
  }

  /// 🆕 NEW: Start listening with separate callbacks for partial and confirmed results
  Future<void> startPatternBasedListening({
    required void Function(SpeechResult) onPartialResult,
    required void Function(SpeechResult) onConfirmedSentence,
    required void Function(Exception) onError,
  }) async {
    if (!(_useContinuousChannel || _isAvailable)) {
      final msg = 'Speech recognition not available';
      print('❌ [STTService] $msg');
      onError(Exception(msg));
      return;
    }

    print('🎤 [STTService] Starting ENHANCED pattern-based listening...');

    _onPartialResult = onPartialResult;
    _onConfirmedSentence = onConfirmedSentence;
    _onError = onError;

    if (_useContinuousChannel) {
      await _startPatternBasedListening();
    } else {
      // Fallback mode - use regular STT but with pattern detection in Dart
      print('⚠️ [STTService] Using fallback mode with Dart pattern detection');
      await _startFallbackListening();
    }
  }

  /// Start listening using pattern-based continuous speech channel
  Future<void> _startPatternBasedListening() async {
    print(
      '🎤 [STTService] Starting PATTERN-BASED listening with locale: $_locale',
    );

    try {
      await _continuousChannel!.startContinuousListening(
        locale: _locale,
        onResult: (result) {
          // 🆕 These are PARTIAL results only - for UI updates
          print(
            '📝 [STTService-Pattern] Partial result: "${result.transcript}"',
          );
          _onPartialResult?.call(result);
        },
        onPatternConfirmedSentence: (result) {
          // 🎯 CRITICAL: These are CONFIRMED complete sentences
          print(
            '🎯 [STTService-Pattern] ✅ CONFIRMED SENTENCE: "${result.transcript}"',
          );
          _onConfirmedSentence?.call(result);
        },
        onError: (error) {
          print('❌ [STTService-Pattern] Error: $error');
          _onError?.call(Exception(error));
        },
      );

      _isListening = true;
      print('✅ [STTService] Pattern-based listening started successfully');
    } catch (e) {
      print('❌ [STTService] Pattern-based listening failed: $e');
      _onError?.call(Exception('Failed to start pattern-based listening: $e'));
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
      await _stopPatternBasedListening();
    } else {
      await _stopFallbackListening();
    }

    _onPartialResult = null;
    _onConfirmedSentence = null;
    _onError = null;

    print('✅ [STTService] Listening stopped');
  }

  Future<void> _stopPatternBasedListening() async {
    try {
      await _continuousChannel?.stopContinuousListening();
      print('✅ [STTService] Pattern-based listening stopped');
    } catch (e) {
      print('⚠️ [STTService] Error stopping pattern-based listening: $e');
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
    _onPartialResult = null;
    _onConfirmedSentence = null;
    _onError = null;

    if (_useContinuousChannel) {
      await _continuousChannel?.stopContinuousListening();
    } else {
      await _speech.cancel();
    }

    print('✅ [STTService] Listening cancelled');
  }

  // Fallback STT handlers
  void _handleFallbackStatus(String status) {
    print('📊 [STTService-Fallback] Status: $status');

    if (status == 'notListening' && _isListening && _onPartialResult != null) {
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

  void _handleFallbackResult(stt.SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    if (transcript.isNotEmpty && _onPartialResult != null) {
      final speechResult = SpeechResult(
        transcript: transcript,
        isFinal: result.finalResult,
        timestamp: DateTime.now(),
        locale: _locale,
      );

      print(
        '📝 [STTService-Fallback] Result: "$transcript" (final: ${result.finalResult})',
      );
      _onPartialResult!(speechResult);

      // 🆕 ENHANCED: For fallback, if we have confirmed callback, use simple pattern detection
      if (result.finalResult && _onConfirmedSentence != null) {
        if (_isSimplePatternComplete(transcript)) {
          print(
            '🎯 [STTService-Fallback] Simple pattern confirms complete sentence',
          );
          final confirmedResult = SpeechResult(
            transcript: transcript,
            isFinal: true,
            timestamp: DateTime.now(),
            locale: _locale,
          );
          _onConfirmedSentence!(confirmedResult);
        } else {
          print(
            '🚫 [STTService-Fallback] Simple pattern: sentence not complete',
          );
        }
      }
    }

    if (result.finalResult && _isListening) {
      _scheduleRestart();
    }
  }

  /// 🆕 Simple pattern detection for fallback mode
  bool _isSimplePatternComplete(String text) {
    final cleanText = text.trim();

    // Must be reasonable length
    if (cleanText.length < 12) return false;

    // Check for clear sentence endings
    if (cleanText.endsWith('.') ||
        cleanText.endsWith('!') ||
        cleanText.endsWith('?')) {
      // Make sure it's not an abbreviation
      if (!_isLikelyAbbreviation(cleanText)) {
        return true;
      }
    }

    // Check for natural transitions indicating complete thoughts
    final transitionPatterns = [
      RegExp(
        r'[.!?]\s+(However|Nevertheless|Therefore|Meanwhile|Furthermore)\s+\w+',
      ),
      RegExp(r'[.!?]\s+(And then|But then|So then|After that)\s+\w+'),
    ];

    for (final pattern in transitionPatterns) {
      if (pattern.hasMatch(cleanText)) {
        return true;
      }
    }

    return false;
  }

  bool _isLikelyAbbreviation(String text) {
    final commonAbbreviations = [
      'Dr.',
      'Mr.',
      'Mrs.',
      'Ms.',
      'Prof.',
      'Inc.',
      'Corp.',
      'Ltd.',
      'etc.',
      'vs.',
      'e.g.',
      'i.e.',
      'U.S.',
      'U.K.',
    ];

    for (final abbrev in commonAbbreviations) {
      if (text.toLowerCase().endsWith(abbrev.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  void _scheduleRestart() {
    if (!_isListening || _onPartialResult == null) return;

    print('🔄 [STTService-Fallback] Scheduling restart...');

    final delay =
        Platform.isAndroid
            ? const Duration(milliseconds: 1200)
            : const Duration(milliseconds: 400);

    Timer(delay, () async {
      if (_isListening && _onPartialResult != null) {
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
    _onPartialResult = null;
    _onConfirmedSentence = null;
    _onError = null;

    _continuousChannel?.dispose();

    print('✅ [STTService] STT service disposed');
  }
}
