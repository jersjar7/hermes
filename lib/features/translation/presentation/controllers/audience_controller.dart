// lib/features/translation/presentation/controllers/audience_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';
import 'package:hermes/features/translation/domain/repositories/transcription_repository.dart';
import 'package:hermes/features/translation/domain/repositories/translation_repository.dart';

/// Controller for audience functionality
@injectable
class AudienceController with ChangeNotifier {
  final TranscriptionRepository _transcriptionRepository;
  final TranslationRepository _translationRepository;
  final Logger _logger;

  StreamSubscription? _transcriptSubscription;
  StreamSubscription? _translationSubscription;

  Session? _activeSession;
  LanguageSelection? _selectedLanguage;

  final List<Transcript> _transcripts = [];
  final List<Translation> _translations = [];
  String _errorMessage = '';
  bool _isConnected = false;

  /// Creates a new [AudienceController]
  AudienceController(
    this._transcriptionRepository,
    this._translationRepository,
    this._logger,
  );

  /// Active session
  Session? get activeSession => _activeSession;

  /// Selected language
  LanguageSelection? get selectedLanguage => _selectedLanguage;

  /// List of transcripts
  List<Transcript> get transcripts => List.unmodifiable(_transcripts);

  /// List of translations
  List<Translation> get translations => List.unmodifiable(_translations);

  /// Error message, if any
  String get errorMessage => _errorMessage;

  /// Whether connected to a session
  bool get isConnected => _isConnected;

  /// Set the active session and language selection
  Future<void> setSessionAndLanguage(
    Session session,
    LanguageSelection language,
  ) async {
    // If already connected to a session, disconnect first
    if (_isConnected) {
      await disconnect();
    }

    _activeSession = session;
    _selectedLanguage = language;

    // Clear existing data
    _transcripts.clear();
    _translations.clear();
    _errorMessage = '';

    notifyListeners();

    // Connect to the session
    await connect();
  }

  /// Connect to the active session and start streaming
  Future<bool> connect() async {
    if (_activeSession == null || _selectedLanguage == null) {
      _errorMessage = 'No active session or language selected';
      notifyListeners();
      return false;
    }

    try {
      // Start streaming transcripts
      _transcriptSubscription = _transcriptionRepository
          .streamSessionTranscripts(_activeSession!.id)
          .listen(
            (result) {
              result.fold(
                (failure) {
                  _errorMessage = failure.message;
                  notifyListeners();
                },
                (transcriptsList) {
                  _transcripts
                    ..clear()
                    ..addAll(transcriptsList);
                  notifyListeners();
                },
              );
            },
            onError: (error) {
              _errorMessage = 'Error streaming transcripts: $error';
              notifyListeners();
              _logger.e('Error streaming transcripts', error: error);
            },
          );

      // Start streaming translations
      _translationSubscription = _translationRepository
          .streamSessionTranslations(
            sessionId: _activeSession!.id,
            targetLanguage: _selectedLanguage!.languageCode,
          )
          .listen(
            (result) {
              result.fold(
                (failure) {
                  _errorMessage = failure.message;
                  notifyListeners();
                },
                (translationsList) {
                  _translations
                    ..clear()
                    ..addAll(translationsList);
                  notifyListeners();
                },
              );
            },
            onError: (error) {
              _errorMessage = 'Error streaming translations: $error';
              notifyListeners();
              _logger.e('Error streaming translations', error: error);
            },
          );

      _isConnected = true;
      notifyListeners();

      return true;
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to connect to session',
        error: e,
        stackTrace: stacktrace,
      );
      _errorMessage = e.toString();
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Change the selected language
  Future<void> changeLanguage(LanguageSelection language) async {
    if (_selectedLanguage?.languageCode == language.languageCode) {
      return;
    }

    // Remember if we were connected
    final wasConnected = _isConnected;

    // Disconnect if connected
    if (_isConnected) {
      await disconnect();
    }

    // Change language
    _selectedLanguage = language;
    _translations.clear();

    notifyListeners();

    // Reconnect if we were connected
    if (wasConnected) {
      await connect();
    }
  }

  /// Disconnect from the session
  Future<void> disconnect() async {
    await _transcriptSubscription?.cancel();
    _transcriptSubscription = null;

    await _translationSubscription?.cancel();
    _translationSubscription = null;

    _isConnected = false;
    notifyListeners();
  }

  /// Get available target languages
  Future<List<String>> getAvailableLanguages() async {
    if (_activeSession == null) {
      return [];
    }

    try {
      final result = await _translationRepository.getAvailableLanguages(
        _activeSession!.sourceLanguage,
      );

      return result.fold((failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return [];
      }, (languages) => languages);
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to get available languages',
        error: e,
        stackTrace: stacktrace,
      );
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
