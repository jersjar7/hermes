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

/// Controller that manages real-time transcription and translation business logic
class RealTimeTranslationController with ChangeNotifier {
  // Dependencies
  final StreamTranscription _streamTranscription;
  final TranslateTextChunk _translateTextChunk;
  final Logger _logger;

  // State
  String _sessionId = '';
  LanguageSelection _sourceLanguage = LanguageSelections.english;
  LanguageSelection _targetLanguage = LanguageSelections.english;
  final List<Transcript> _transcripts = [];
  final List<Translation> _translations = [];
  String _currentPartialTranscript = '';
  String _lastTranslatedText = '';
  bool _isListening = false;
  String? _errorMessage;

  // Streams and subscriptions
  StreamSubscription? _transcriptionSubscription;
  Timer? _translationDebounceTimer;

  // Getters
  List<Transcript> get transcripts => List.unmodifiable(_transcripts);
  List<Translation> get translations => List.unmodifiable(_translations);
  String get currentPartialTranscript => _currentPartialTranscript;
  bool get isListening => _isListening;
  String? get errorMessage => _errorMessage;

  /// Creates a new [RealTimeTranslationController]
  RealTimeTranslationController({
    StreamTranscription? streamTranscription,
    TranslateTextChunk? translateTextChunk,
    Logger? logger,
  }) : _streamTranscription =
           streamTranscription ?? GetIt.instance<StreamTranscription>(),
       _translateTextChunk =
           translateTextChunk ?? GetIt.instance<TranslateTextChunk>(),
       _logger = logger ?? GetIt.instance<Logger>();

  /// Initialize the controller with session and language settings
  void initialize({
    required String sessionId,
    required LanguageSelection sourceLanguage,
    required LanguageSelection targetLanguage,
    bool autoStart = false,
  }) {
    _sessionId = sessionId;
    _sourceLanguage = sourceLanguage;
    _targetLanguage = targetLanguage;

    if (autoStart) {
      startListening();
    }
  }

  /// Start listening for transcription
  Future<bool> startListening() async {
    if (_isListening || _sessionId.isEmpty) {
      return false;
    }

    _logger.d("[DEBUG] Starting to listen for transcription");
    _isListening = true;
    _errorMessage = null;
    notifyListeners();

    final params = StreamTranscriptionParams(
      sessionId: _sessionId,
      languageCode: _sourceLanguage.languageCode,
    );

    // Start streaming transcription
    try {
      _logger.d("[DEBUG] About to call _streamTranscription");
      final transcriptionStream = _streamTranscription(params);
      _logger.d("[DEBUG] Got transcription stream");

      _transcriptionSubscription = transcriptionStream.listen(
        (result) {
          _logger.d("[DEBUG] Received transcription result: $result");
          result.fold(
            (failure) {
              _logger.d("[DEBUG] Transcription failure: ${failure.message}");
              _errorMessage = failure.message;
              _isListening = false;
              notifyListeners();
            },
            (transcript) {
              _logger.d("[DEBUG] Transcription success: ${transcript.text}");

              // For final transcripts, add to list and translate
              if (transcript.isFinal) {
                // Only add if text is not empty
                if (transcript.text.trim().isNotEmpty) {
                  _transcripts.add(transcript);
                  _translateTranscript(transcript);
                  _currentPartialTranscript = '';
                  notifyListeners();
                }
              } else {
                // Update partial transcript
                _currentPartialTranscript = transcript.text;

                // Debounce translation of partial transcripts
                _debouncedTranslate(transcript);
                notifyListeners();
              }
            },
          );
        },
        onError: (error) {
          _logger.d("[DEBUG] Transcription stream error: $error");
          _errorMessage = error.toString();
          _isListening = false;
          notifyListeners();
        },
        onDone: () {
          _logger.d("[DEBUG] Transcription stream closed");
          _isListening = false;
          notifyListeners();
        },
      );

      return true;
    } catch (e) {
      _logger.d("[DEBUG] Exception when starting transcription: $e");
      _errorMessage = "Error starting transcription: $e";
      _isListening = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop listening for transcription
  Future<void> stopListening() async {
    if (!_isListening) return;

    await _transcriptionSubscription?.cancel();
    _transcriptionSubscription = null;

    await _streamTranscription.stop();

    _isListening = false;
    notifyListeners();
  }

  /// Toggle listening state
  void toggleListening() {
    if (_isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  /// Clear all transcripts and translations
  void clearTranscripts() {
    _transcripts.clear();
    _translations.clear();
    _currentPartialTranscript = '';
    notifyListeners();
  }

  /// Called when target language changes
  void changeTargetLanguage(LanguageSelection language) {
    if (_targetLanguage.languageCode == language.languageCode) {
      return;
    }

    _targetLanguage = language;
    _translations.clear();
    _lastTranslatedText = '';
    notifyListeners();

    // Re-translate existing transcripts with new target language
    for (final transcript in _transcripts) {
      _translateTranscript(transcript);
    }
  }

  /// Translate a transcript after a delay (for partial transcripts)
  void _debouncedTranslate(Transcript transcript) {
    _translationDebounceTimer?.cancel();

    // Only translate partial transcripts if they're stable enough
    if (transcript.text.length > 10) {
      _translationDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _translateTranscript(transcript, isPartial: true);
      });
    }
  }

  /// Translate a transcript
  Future<void> _translateTranscript(
    Transcript transcript, {
    bool isPartial = false,
  }) async {
    // Skip translation if target language is the same as source language
    if (_targetLanguage.languageCode == _sourceLanguage.languageCode) {
      return;
    }

    // Skip if text is empty or the same as the last translated text
    if (transcript.text.trim().isEmpty ||
        transcript.text == _lastTranslatedText) {
      return;
    }

    final params = TranslateTextChunkParams(
      sessionId: _sessionId,
      sourceText: transcript.text,
      sourceLanguage: _sourceLanguage.languageCode,
      targetLanguage: _targetLanguage.languageCode,
    );

    final result = await _translateTextChunk(params);

    result.fold(
      (failure) {
        // Only show error for final translations
        if (!isPartial) {
          _errorMessage = failure.message;
          notifyListeners();
        }
      },
      (translation) {
        // For partial translations, replace the last one if it exists
        if (isPartial && _translations.isNotEmpty) {
          _translations.removeLast();
        }

        _translations.add(translation);
        _lastTranslatedText = transcript.text;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    stopListening();
    _translationDebounceTimer?.cancel();
    super.dispose();
  }
}
