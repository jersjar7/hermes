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

  Future<bool> startListening() async {
    if (_isDisposed || _isListening || _sessionId.isEmpty) return false;

    _logger.d("[DEBUG] Starting to listen for transcription");
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
        },
        onDone: () {
          if (_isDisposed) return;
          _isListening = false;
          _safeNotifyListeners();
        },
      );

      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _errorMessage = "Error starting transcription: $e";
      _isListening = false;
      _safeNotifyListeners();
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isDisposed || !_isListening) return;

    await _transcriptionSubscription?.cancel();
    _transcriptionSubscription = null;

    await _streamTranscription.stop();
    _isListening = false;
    _safeNotifyListeners();
  }

  void toggleListening() {
    if (_isDisposed) return;
    if (_isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void clearTranscripts() {
    if (_isDisposed) return;
    _transcripts.clear();
    _translations.clear();
    _currentPartialTranscript = '';
    _safeNotifyListeners();
  }

  void changeTargetLanguage(LanguageSelection language) {
    if (_isDisposed) return;
    if (_targetLanguage.languageCode == language.languageCode) return;

    _targetLanguage = language;
    _translations.clear();
    _lastTranslatedText = '';
    _safeNotifyListeners();

    for (final transcript in _transcripts) {
      _translateTranscript(transcript);
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

    final result = await _translateTextChunk(params);

    if (_isDisposed) return;

    result.fold(
      (failure) {
        if (!isPartial) {
          _errorMessage = failure.message;
          _safeNotifyListeners();
        }
      },
      (translation) {
        if (isPartial && _translations.isNotEmpty) {
          _translations.removeLast();
        }
        _translations.add(translation);
        _lastTranslatedText = transcript.text;
        _safeNotifyListeners();
      },
    );
  }

  void _safeNotifyListeners() {
    if (_isDisposed) {
      assert(false, "Tried to notifyListeners after controller was disposed.");
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopListening();
    _translationDebounceTimer?.cancel();
    super.dispose();
  }
}
