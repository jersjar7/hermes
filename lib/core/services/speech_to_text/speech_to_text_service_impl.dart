// lib/core/services/speech_to_text/speech_to_text_service_impl.dart

import 'dart:async';
import 'dart:io'; // Add this import
import 'package:speech_to_text/speech_recognition_error.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../logger/logger_service.dart';
import 'speech_to_text_service.dart';
import 'speech_result.dart';
import 'continuous_speech_channel.dart'; // Add this import

class SpeechToTextServiceImpl implements ISpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ILoggerService _logger;
  bool _isAvailable = false;
  bool _isListening = false;
  String _locale = 'en-US';

  // 🎯 NEW: Continuous speech recognition support
  final ContinuousSpeechChannel _continuousChannel =
      ContinuousSpeechChannel.instance;
  bool _useContinuousRecognition = false;
  bool _continuousAvailable = false;

  // For managing finalization timeouts (existing plugin logic)
  Timer? _finalizationTimer;
  Timer? _restartTimer;
  String? _lastPartialResult;
  void Function(SpeechResult)? _currentOnResult;
  void Function(Exception)? _currentOnError;

  // Timeout after which we consider a partial result "final"
  static const Duration _finalizationTimeout = Duration(seconds: 2);
  static const Duration _restartDelay = Duration(milliseconds: 500);

  SpeechToTextServiceImpl(this._logger);

  @override
  Future<bool> initialize() async {
    print('🎙️ [STTService] Initializing speech-to-text service...');

    try {
      // 🎯 NEW: Check if continuous recognition is available (iOS only for now)
      if (Platform.isIOS || Platform.isAndroid) {
        _continuousAvailable = await _continuousChannel.isAvailable;
        if (_continuousAvailable) {
          print(
            '✨ [STTService] Continuous recognition available! Initializing...',
          );
          final continuousReady = await _continuousChannel.initialize();
          if (continuousReady) {
            _useContinuousRecognition = true;
            print(
              '🚀 [STTService] Continuous recognition enabled - no more gaps!',
            );
          } else {
            print(
              '⚠️ [STTService] Continuous recognition init failed, using fallback',
            );
          }
        } else {
          print(
            '📱 [STTService] Continuous recognition not available, using standard plugin',
          );
        }
      }

      // Initialize standard plugin as fallback or main method
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          // Only handle status for standard plugin when not using continuous
          if (!_useContinuousRecognition) {
            print('🎙️ [STTService] Status changed: $status');
            _logger.logInfo('STT status: $status', context: 'STT');

            final wasListening = _isListening;
            _isListening = status == 'listening';

            // Handle status changes
            if (status == 'notListening' || status == 'done') {
              _handlePotentialFinalization();

              // Auto-restart listening if we were in a listening session
              if (wasListening && _currentOnResult != null) {
                _scheduleRestart();
              }
            }
          }
        },
        onError: (err) {
          // Handle errors for both modes
          print('❌ [STTService] Error: $err');
          _logger.logError('STT error: $err', context: 'STT');
          if (!_useContinuousRecognition) {
            _handleSpeechError(err);
          }
        },
      );

      print(
        '📱 [STTService] Standard plugin initialization result: $_isAvailable',
      );
      print(
        '🎯 [STTService] Using continuous recognition: $_useContinuousRecognition',
      );

      if (_isAvailable || _useContinuousRecognition) {
        final locales = await _speech.locales();
        print('🌍 [STTService] Available locales: ${locales.length}');
      } else {
        print(
          '⚠️ [STTService] Speech recognition not available on this device',
        );
      }

      return _isAvailable || _useContinuousRecognition;
    } catch (e, stackTrace) {
      print('💥 [STTService] Initialization failed: $e');
      _logger.logError(
        'STT initialization failed',
        error: e,
        stackTrace: stackTrace,
        context: 'STT',
      );
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(SpeechResult) onResult,
    required void Function(Exception) onError,
  }) async {
    if (!_isAvailable && !_useContinuousRecognition) {
      final msg = 'Speech recognition not available';
      print('❌ [STTService] $msg');
      onError(Exception(msg));
      return;
    }

    // 🎯 NEW: Use continuous recognition if available
    if (_useContinuousRecognition) {
      print(
        '🚀 [STTService] Starting CONTINUOUS listening (no gaps!) with locale: $_locale',
      );

      // Store callbacks for stop/cancel operations
      _currentOnResult = onResult;
      _currentOnError = onError;

      try {
        await _continuousChannel.startContinuousListening(
          locale: _locale,
          onResult: (result) {
            // 🎯 CRITICAL: Check if callback still exists before calling
            if (_currentOnResult != null) {
              _currentOnResult!(result);
            }
          },
          onError: (errorMessage) {
            // 🎯 CRITICAL: Check if callback still exists before calling
            if (_currentOnError != null) {
              _currentOnError!(Exception(errorMessage));
            }
          },
        );

        _isListening = true;
        print('✅ [STTService] Continuous listening started successfully');
      } catch (e) {
        print('❌ [STTService] Continuous listening failed: $e');
        _currentOnResult = null;
        _currentOnError = null;
        onError(Exception('Continuous listening failed: $e'));
      }
      return;
    }

    // 🎯 FALLBACK: Use standard plugin logic
    print('🎤 [STTService] Starting standard listening with locale: $_locale');

    // Store callbacks
    _currentOnResult = onResult;
    _currentOnError = onError;

    await _startListeningInternal();
  }

  Future<void> _startListeningInternal() async {
    try {
      await _speech.listen(
        localeId: _locale,
        onResult: (res) {
          final transcript = res.recognizedWords.trim();
          final isFinal = res.finalResult;

          print(
            '📝 [STTService] Result: "$transcript" (final: $isFinal, confidence: ${res.confidence})',
          );

          if (transcript.isNotEmpty) {
            if (isFinal) {
              // Clear timers and emit final result
              _finalizationTimer?.cancel();
              _lastPartialResult = null;

              final out = SpeechResult(
                transcript: transcript,
                isFinal: true,
                timestamp: DateTime.now(),
                locale: _locale,
              );

              // 🎯 CRITICAL: Check if callback still exists before calling
              if (_currentOnResult != null) {
                _currentOnResult!(out);
              }

              // Continue listening for more speech
              _scheduleRestart();
            } else {
              // Handle partial result
              _lastPartialResult = transcript;

              final out = SpeechResult(
                transcript: transcript,
                isFinal: false,
                timestamp: DateTime.now(),
                locale: _locale,
              );

              // 🎯 CRITICAL: Check if callback still exists before calling
              if (_currentOnResult != null) {
                _currentOnResult!(out);
              }

              // Set up finalization timer
              _startFinalizationTimer();
            }
          }
        },
        cancelOnError: false, // Don't cancel on errors, handle them gracefully
        partialResults: true,
        listenFor: const Duration(seconds: 30), // Listen for longer periods
        pauseFor: const Duration(seconds: 3), // Pause detection after 3 seconds
      );
    } catch (e) {
      print('❌ [STTService] Start listening failed: $e');
      _handleSpeechError(stt.SpeechRecognitionError('start_error', true));
    }
  }

  // [Rest of the existing methods remain the same, but modified for continuous support]

  @override
  Future<void> stopListening() async {
    print('🛑 [STTService] Stopping listening...');

    // 🎯 NEW: Handle continuous recognition
    if (_useContinuousRecognition && _isListening) {
      try {
        await _continuousChannel.stopContinuousListening();
        print('✅ [STTService] Continuous recognition stopped');
      } catch (e) {
        print('⚠️ [STTService] Error stopping continuous recognition: $e');
      }
    }

    // 🎯 CRITICAL: Clear callbacks FIRST to stop processing new results
    final oldOnResult = _currentOnResult;

    _currentOnResult = null;
    _currentOnError = null;

    // Cancel timers
    _finalizationTimer?.cancel();
    _finalizationTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;

    // Finalize any pending result ONLY if we had active callbacks
    if (oldOnResult != null && !_useContinuousRecognition) {
      _handlePotentialFinalization();
    }

    // Stop the standard speech service (if using it)
    if (!_useContinuousRecognition) {
      try {
        await _speech.stop();
        print('✅ [STTService] Standard speech service stopped');
      } catch (e) {
        print('⚠️ [STTService] Error stopping standard speech service: $e');
      }
    }

    _isListening = false;
    _lastPartialResult = null;

    print('✅ [STTService] Listening stopped completely');
  }

  @override
  Future<void> cancel() async {
    print('❌ [STTService] Cancelling listening...');

    // 🎯 NEW: Handle continuous recognition
    if (_useContinuousRecognition && _isListening) {
      try {
        await _continuousChannel.stopContinuousListening();
        print('✅ [STTService] Continuous recognition cancelled');
      } catch (e) {
        print('⚠️ [STTService] Error cancelling continuous recognition: $e');
      }
    }

    // 🎯 CRITICAL: Clear everything immediately
    _currentOnResult = null;
    _currentOnError = null;
    _finalizationTimer?.cancel();
    _finalizationTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;

    if (!_useContinuousRecognition) {
      try {
        await _speech.cancel();
        print('✅ [STTService] Standard speech service cancelled');
      } catch (e) {
        print('⚠️ [STTService] Error cancelling standard speech service: $e');
      }
    }

    _isListening = false;
    _lastPartialResult = null;

    print('✅ [STTService] Listening cancelled completely');
  }

  // [All other existing methods remain unchanged...]

  void _handleSpeechError(stt.SpeechRecognitionError error) {
    print('🔧 [STTService] Handling speech error: ${error.errorMsg}');

    // Handle different types of errors
    switch (error.errorMsg) {
      case 'error_no_match':
        // 🎯 MORE FORGIVING: Don't treat no_match as critical on Android
        if (Platform.isAndroid) {
          print('🔄 [STTService] Android no-match (normal), continuing...');
          _scheduleRestart(
            delay: const Duration(milliseconds: 100),
          ); // Faster restart
        } else {
          print('🔄 [STTService] No speech detected, restarting...');
          _scheduleRestart();
        }
        break;

      case 'error_speech_timeout':
        // Speech timeout - restart listening
        print('🔄 [STTService] Speech timeout, restarting...');
        _scheduleRestart(delay: const Duration(milliseconds: 200));
        break;

      case 'error_audio':
        // Audio error - might be temporary, try restarting
        print('🔄 [STTService] Audio error, attempting restart...');
        _scheduleRestart(delay: const Duration(milliseconds: 500));
        break;

      case 'error_network':
        // Network error - inform user but try to restart
        print('🌐 [STTService] Network error, will retry...');
        if (_currentOnError != null) {
          _currentOnError!(Exception('Network error, retrying...'));
        }
        _scheduleRestart(delay: const Duration(seconds: 1));
        break;

      default:
        // Other errors - inform user
        print('❌ [STTService] Unhandled error: ${error.errorMsg}');
        if (error.permanent && _currentOnError != null) {
          _currentOnError!(
            Exception('Speech recognition error: ${error.errorMsg}'),
          );
        } else {
          _scheduleRestart(delay: const Duration(milliseconds: 300));
        }
        break;
    }
  }

  // Update _scheduleRestart to accept custom delay
  void _scheduleRestart({Duration? delay}) {
    if (_currentOnResult == null || _useContinuousRecognition) return;

    _restartTimer?.cancel();

    // 🎯 ANDROID OPTIMIZATION: Faster restarts
    final restartDelay =
        delay ??
        (Platform.isAndroid
            ? const Duration(milliseconds: 100)
            : _restartDelay);

    _restartTimer = Timer(restartDelay, () {
      if (_currentOnResult != null &&
          _isAvailable &&
          !_useContinuousRecognition) {
        print(
          '🔄 [STTService] Auto-restarting listening (${restartDelay.inMilliseconds}ms delay)...',
        );
        _startListeningInternal();
      }
    });
  }

  void _startFinalizationTimer() {
    _finalizationTimer?.cancel();
    _finalizationTimer = Timer(_finalizationTimeout, () {
      _handlePotentialFinalization();
    });
  }

  void _handlePotentialFinalization() {
    // 🎯 CRITICAL: Only finalize if we still have active callbacks and not using continuous
    if (_lastPartialResult != null &&
        _lastPartialResult!.isNotEmpty &&
        _currentOnResult != null &&
        !_useContinuousRecognition) {
      print('⏰ [STTService] Finalizing partial result: "$_lastPartialResult"');

      final finalResult = SpeechResult(
        transcript: _lastPartialResult!,
        isFinal: true,
        timestamp: DateTime.now(),
        locale: _locale,
      );

      // Double-check callback still exists before calling
      if (_currentOnResult != null) {
        _currentOnResult!(finalResult);
      }
      _lastPartialResult = null;
    }

    _finalizationTimer?.cancel();
    _finalizationTimer = null;
  }

  @override
  bool get isAvailable => _isAvailable || _useContinuousRecognition;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async =>
      _isAvailable || _useContinuousRecognition;

  @override
  Future<void> setLocale(String localeId) async {
    print('🌍 [STTService] Setting locale to: $localeId');

    // 🎯 NEW: Just store the locale - continuous recognition will use it directly
    if (_useContinuousRecognition) {
      _locale = localeId;
      print('✅ [STTService] Locale set for continuous recognition: $_locale');
      return;
    }

    // [Rest of existing setLocale logic for standard plugin...]

    // Validate that the locale is supported
    final supportedLocales = await getSupportedLocales();

    // Check for exact match first
    bool isSupported = supportedLocales.any(
      (locale) => locale.localeId.toLowerCase() == localeId.toLowerCase(),
    );

    // If no exact match, try with format conversion (dash <-> underscore)
    if (!isSupported) {
      final alternateFormat =
          localeId.contains('-')
              ? localeId.replaceAll('-', '_')
              : localeId.replaceAll('_', '-');

      isSupported = supportedLocales.any(
        (locale) =>
            locale.localeId.toLowerCase() == alternateFormat.toLowerCase(),
      );

      if (isSupported) {
        print('🔄 [STTService] Using alternate format: $alternateFormat');
        _locale = alternateFormat;
        print('✅ [STTService] Successfully set locale to: $_locale');
        return;
      }
    }

    // If still no match, try language part only (e.g., 'es' from 'es-ES')
    if (!isSupported) {
      final languagePart = localeId.split(RegExp(r'[-_]'))[0];
      isSupported = supportedLocales.any(
        (locale) =>
            locale.localeId.split(RegExp(r'[-_]'))[0].toLowerCase() ==
            languagePart.toLowerCase(),
      );

      if (isSupported) {
        // Find the first matching locale for this language
        final matchingLocale = supportedLocales.firstWhere(
          (locale) =>
              locale.localeId.split(RegExp(r'[-_]'))[0].toLowerCase() ==
              languagePart.toLowerCase(),
        );
        print(
          '🔄 [STTService] Using available variant: ${matchingLocale.localeId}',
        );
        _locale = matchingLocale.localeId;
        print('✅ [STTService] Successfully set locale to: $_locale');
        return;
      }
    }

    if (!isSupported) {
      print(
        '⚠️ [STTService] Locale $localeId not supported, falling back to en-US',
      );
      _logger.logError(
        'Unsupported locale: $localeId, available: ${supportedLocales.map((l) => l.localeId).join(", ")}',
        context: 'STT',
      );
      // Fall back to English but log the issue
      _locale = 'en-US'; // Use dash format for iOS
      return;
    }

    _locale = localeId;
    print('✅ [STTService] Successfully set locale to: $_locale');
  }

  @override
  Future<List<LocaleName>> getSupportedLocales() async {
    try {
      final locales = await _speech.locales();
      print(
        '📋 [STTService] Available locales: ${locales.map((l) => l.localeId).take(10).join(", ")}...',
      );
      return locales
          .map((e) => LocaleName(localeId: e.localeId, name: e.name))
          .toList();
    } catch (e) {
      print('❌ [STTService] Failed to get supported locales: $e');
      return [];
    }
  }

  @override
  void dispose() {
    print('🗑️ [STTService] Disposing STT service...');

    // 🎯 NEW: Dispose continuous channel
    _continuousChannel.dispose();

    _finalizationTimer?.cancel();
    _finalizationTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    _currentOnResult = null;
    _currentOnError = null;
    _lastPartialResult = null;

    print('✅ [STTService] STT service disposed');
  }
}
