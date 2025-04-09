// lib/features/translation/presentation/controllers/speaker_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/usecases/stream_transcription.dart';

/// Controller for speaker functionality
@injectable
class SpeakerController with ChangeNotifier {
  final StreamTranscription _streamTranscription;
  final Logger _logger;

  StreamSubscription? _transcriptionSubscription;
  bool _isListening = false;
  String _errorMessage = '';
  Session? _activeSession;
  final List<Transcript> _transcripts = [];
  String _partialTranscript = '';

  /// Creates a new [SpeakerController]
  SpeakerController(this._streamTranscription, this._logger);

  /// Whether the speaker is currently listening
  bool get isListening => _isListening;

  /// Error message, if any
  String get errorMessage => _errorMessage;

  /// Active session
  Session? get activeSession => _activeSession;

  /// List of transcripts
  List<Transcript> get transcripts => List.unmodifiable(_transcripts);

  /// Current partial transcript
  String get partialTranscript => _partialTranscript;

  /// Set the active session
  void setActiveSession(Session session) {
    _activeSession = session;
    notifyListeners();
  }

  /// Start listening for transcription
  Future<bool> startListening() async {
    if (_isListening || _activeSession == null) {
      return false;
    }

    _errorMessage = '';
    _isListening = true;
    _partialTranscript = '';
    notifyListeners();

    final params = StreamTranscriptionParams(
      sessionId: _activeSession!.id,
      languageCode: _activeSession!.sourceLanguage,
    );

    try {
      final transcriptionStream = _streamTranscription(params);

      _transcriptionSubscription = transcriptionStream.listen(
        (result) {
          result.fold(
            (failure) {
              _errorMessage = failure.message;
              _isListening = false;
              notifyListeners();
            },
            (transcript) {
              if (transcript.isFinal) {
                if (transcript.text.trim().isNotEmpty) {
                  _transcripts.add(transcript);
                  _partialTranscript = '';
                }
              } else {
                _partialTranscript = transcript.text;
              }
              notifyListeners();
            },
          );
        },
        onError: (error) {
          _errorMessage = error.toString();
          _isListening = false;
          notifyListeners();
          _logger.e('Error in transcription stream', error: error);
        },
        onDone: () {
          _isListening = false;
          notifyListeners();
        },
      );

      return true;
    } catch (e, stacktrace) {
      _logger.e('Failed to start listening', error: e, stackTrace: stacktrace);
      _errorMessage = e.toString();
      _isListening = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop listening for transcription
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;

      await _streamTranscription.stop();

      _isListening = false;
      notifyListeners();
    } catch (e, stacktrace) {
      _logger.e('Failed to stop listening', error: e, stackTrace: stacktrace);
    }
  }

  /// Clear all transcripts
  void clearTranscripts() {
    _transcripts.clear();
    _partialTranscript = '';
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    _transcriptionSubscription?.cancel();
    super.dispose();
  }
}
