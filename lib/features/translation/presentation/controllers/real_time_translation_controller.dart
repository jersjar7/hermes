// lib/features/translation/presentation/controllers/real_time_translation_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';
import 'package:hermes/features/translation/domain/usecases/stream_transcription.dart';
import 'package:hermes/features/translation/domain/usecases/translate_text_chunk.dart';

class RealTimeTranslationController with ChangeNotifier {
  bool _isDisposed = false;
  final StreamTranscription _streamTranscription;
  final TranslateTextChunk _translateTextChunk;
  final Logger _logger;

  String _sessionId = '';
  LanguageSelection _sourceLanguage = LanguageSelections.english;
  LanguageSelection _targetLanguage = LanguageSelections.english;
  final List<Transcript> _transcripts = [];
  final List<Translation> _translations = [];
  String _currentPartialTranscript = '';
  String _lastTranslatedText = '';
  bool _isListening = false;
  String? _errorMessage;

  StreamSubscription? _transcriptionSubscription;
  Timer? _translationDebounceTimer;

  List<Transcript> get transcripts => List.unmodifiable(_transcripts);
  List<Translation> get translations => List.unmodifiable(_translations);
  String get currentPartialTranscript => _currentPartialTranscript;
  bool get isListening => _isListening;
  String? get errorMessage => _errorMessage;

  RealTimeTranslationController({
    StreamTranscription? streamTranscription,
    TranslateTextChunk? translateTextChunk,
    Logger? logger,
  }) : _streamTranscription =
           streamTranscription ?? GetIt.instance<StreamTranscription>(),
       _translateTextChunk =
           translateTextChunk ?? GetIt.instance<TranslateTextChunk>(),
       _logger = logger ?? GetIt.instance<Logger>();

  /// Initialize the controller
  /// Returns a Future to allow error handling in the widget
  Future<void> initialize({
    required String sessionId,
    required LanguageSelection sourceLanguage,
    required LanguageSelection targetLanguage,
    bool autoStart = false,
  }) async {
    try {
      _sessionId = sessionId;
      _sourceLanguage = sourceLanguage;
      _targetLanguage = targetLanguage;

      _logger.d(
        "[RT_CONTROLLER] Initialized with sessionId=$sessionId, "
        "sourceLanguage=${sourceLanguage.languageCode}, "
        "targetLanguage=${targetLanguage.languageCode}",
      );

      if (autoStart) {
        await startListening();
      }
    } catch (e, stackTrace) {
      _logger.e(
        "[RT_CONTROLLER] Error during initialization",
        error: e,
        stackTrace: stackTrace,
      );
      _errorMessage = "Initialization error: $e";

      // Rethrow to allow caller to handle
      rethrow;
    }
  }

  Future<bool> startListening() async {
    if (_isDisposed || _isListening || _sessionId.isEmpty) return false;

    _logger.d("[RT_CONTROLLER] Starting to listen for transcription");
    _isListening = true;
    _errorMessage = null;
    _safeNotifyListeners();

    final params = StreamTranscriptionParams(
      sessionId: _sessionId,
      languageCode: _sourceLanguage.languageCode,
    );

    try {
      final transcriptionStream = _streamTranscription(params);
      _transcriptionSubscription = transcriptionStream.listen(
        (result) {
          if (_isDisposed) return;

          result.fold(
            (failure) {
              _errorMessage = failure.message;
              _isListening = false;
              _safeNotifyListeners();
            },
            (transcript) {
              if (_isDisposed) return;

              if (transcript.isFinal) {
                if (transcript.text.trim().isNotEmpty) {
                  _transcripts.add(transcript);
                  _translateTranscript(transcript);
                  _currentPartialTranscript = '';
                  _safeNotifyListeners();
                }
              } else {
                _currentPartialTranscript = transcript.text;
                _debouncedTranslate(transcript);
                _safeNotifyListeners();
              }
            },
          );
        },
        onError: (error) {
          if (_isDisposed) return;
          _errorMessage = error.toString();
          _isListening = false;
          _safeNotifyListeners();
          _logger.e(
            "[RT_CONTROLLER] Error in transcription stream",
            error: error,
          );
        },
        onDone: () {
          if (_isDisposed) return;
          _isListening = false;
          _safeNotifyListeners();
          _logger.d("[RT_CONTROLLER] Transcription stream completed");
        },
      );

      return true;
    } catch (e, stackTrace) {
      if (_isDisposed) return false;
      _errorMessage = "Error starting transcription: $e";
      _isListening = false;
      _safeNotifyListeners();
      _logger.e(
        "[RT_CONTROLLER] Failed to start listening",
        error: e,
        stackTrace: stackTrace,
      );

      // Rethrow to allow caller to handle
      rethrow;
    }
  }

  Future<void> stopListening() async {
    if (_isDisposed || !_isListening) return;

    _logger.d("[RT_CONTROLLER] Stopping listening");

    try {
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;

      await _streamTranscription.stop();
      _isListening = false;
      _safeNotifyListeners();

      _logger.d("[RT_CONTROLLER] Listening stopped successfully");
    } catch (e, stackTrace) {
      _logger.e(
        "[RT_CONTROLLER] Error stopping listening",
        error: e,
        stackTrace: stackTrace,
      );
      _errorMessage = "Error stopping transcription: $e";
      _safeNotifyListeners();

      // Rethrow to allow caller to handle
      rethrow;
    }
  }

  void toggleListening() async {
    if (_isDisposed) return;
    try {
      if (_isListening) {
        await stopListening();
      } else {
        await startListening();
      }
    } catch (e) {
      _logger.e("[RT_CONTROLLER] Error toggling listening state", error: e);
    }
  }

  void clearTranscripts() {
    if (_isDisposed) return;
    _transcripts.clear();
    _translations.clear();
    _currentPartialTranscript = '';
    _safeNotifyListeners();
  }

  Future<void> changeTargetLanguage(LanguageSelection language) async {
    if (_isDisposed) return;
    if (_targetLanguage.languageCode == language.languageCode) return;

    _logger.d(
      "[RT_CONTROLLER] Changing target language from ${_targetLanguage.languageCode} to ${language.languageCode}",
    );

    _targetLanguage = language;
    _translations.clear();
    _lastTranslatedText = '';
    _safeNotifyListeners();

    // Re-translate existing transcripts with new target language
    for (final transcript in _transcripts) {
      try {
        await _translateTranscript(transcript);
      } catch (e) {
        _logger.e(
          "[RT_CONTROLLER] Error translating transcript to new language",
          error: e,
        );
      }
    }
  }

  void _debouncedTranslate(Transcript transcript) {
    _translationDebounceTimer?.cancel();
    if (transcript.text.length > 10) {
      _translationDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isDisposed) return;
        _translateTranscript(transcript, isPartial: true);
      });
    }
  }

  Future<void> _translateTranscript(
    Transcript transcript, {
    bool isPartial = false,
  }) async {
    if (_isDisposed ||
        _targetLanguage.languageCode == _sourceLanguage.languageCode ||
        transcript.text.trim().isEmpty ||
        transcript.text == _lastTranslatedText)
      return;

    final params = TranslateTextChunkParams(
      sessionId: _sessionId,
      sourceText: transcript.text,
      sourceLanguage: _sourceLanguage.languageCode,
      targetLanguage: _targetLanguage.languageCode,
    );

    try {
      final result = await _translateTextChunk(params);

      if (_isDisposed) return;

      result.fold(
        (failure) {
          if (!isPartial) {
            _errorMessage = failure.message;
            _safeNotifyListeners();
          }
          _logger.e("[RT_CONTROLLER] Translation failure", error: failure);
        },
        (translation) {
          if (isPartial && _translations.isNotEmpty) {
            _translations.removeLast();
          }
          _translations.add(translation);
          _lastTranslatedText = transcript.text;
          _safeNotifyListeners();

          _logger.d(
            "[RT_CONTROLLER] Translation successful: ${translation.sourceText.substring(0, min(20, translation.sourceText.length))}... => ${translation.targetText.substring(0, min(20, translation.targetText.length))}...",
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.e(
        "[RT_CONTROLLER] Error translating transcript",
        error: e,
        stackTrace: stackTrace,
      );
      if (!isPartial) {
        _errorMessage = "Translation error: $e";
        _safeNotifyListeners();
      }
    }
  }

  void _safeNotifyListeners() {
    if (_isDisposed) {
      _logger.w(
        "[RT_CONTROLLER] Attempted to notify listeners after controller was disposed.",
      );
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _logger.d("[RT_CONTROLLER] Disposing controller");

    // Cancel any ongoing operations
    _translationDebounceTimer?.cancel();
    stopListening().catchError((e) {
      _logger.e("[RT_CONTROLLER] Error during disposal", error: e);
    });

    super.dispose();
  }

  // Helper function for safe string truncation
  int min(int a, int b) => a < b ? a : b;
}
