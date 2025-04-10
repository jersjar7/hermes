// lib/features/translation/presentation/controllers/speaker_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hermes/features/translation/infrastructure/services/speech_to_text_service.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/usecases/stream_transcription.dart';
import 'package:permission_handler/permission_handler.dart';

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
  SpeakerController(this._streamTranscription, this._logger) {
    print("[CONTROLLER_DEBUG] SpeakerController initialized");
  }

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
    print("[CONTROLLER_DEBUG] Setting active session: ${session.id}");
    _activeSession = session;
    notifyListeners();
  }

  /// Start listening for transcription
  Future<bool> startListening() async {
    print("[CONTROLLER_DEBUG] startListening called");
    print(
      "[CONTROLLER_DEBUG] _isListening=$_isListening, _activeSession=${_activeSession != null}",
    );

    if (_isListening || _activeSession == null) {
      print(
        "[CONTROLLER_DEBUG] Cannot start listening: ${_isListening ? 'already listening' : 'no active session'}",
      );
      return false;
    }

    _errorMessage = '';
    notifyListeners();

    // STEP 1: Check microphone permission
    final permissionStatus = await Permission.microphone.status;
    print(
      "[CONTROLLER_DEBUG] Current microphone permission status: $permissionStatus",
    );

    if (permissionStatus.isPermanentlyDenied) {
      print("[CONTROLLER_DEBUG] Microphone permission is permanently denied");
      _errorMessage =
          'Microphone permission is permanently denied. Please enable it in settings.';
      notifyListeners();
      return false;
    }

    if (permissionStatus.isDenied) {
      print("[CONTROLLER_DEBUG] Requesting microphone permission");
      final requestResult = await Permission.microphone.request();
      print("[CONTROLLER_DEBUG] Permission request result: $requestResult");

      if (!requestResult.isGranted) {
        _errorMessage =
            requestResult.isPermanentlyDenied
                ? 'Microphone permission is permanently denied. Please enable it in settings.'
                : 'Microphone permission is required to start listening.';
        print("[CONTROLLER_DEBUG] Permission not granted: $_errorMessage");
        notifyListeners();
        return false;
      }

      print("[CONTROLLER_DEBUG] Permission granted after request");
    } else {
      print("[CONTROLLER_DEBUG] Microphone permission already granted");
    }

    // STEP 2: Begin transcription
    _isListening = true;
    _partialTranscript = '';
    notifyListeners();
    print("[CONTROLLER_DEBUG] Set state to listening and notified listeners");

    final params = StreamTranscriptionParams(
      sessionId: _activeSession!.id,
      languageCode: _activeSession!.sourceLanguage,
    );
    print("[CONTROLLER_DEBUG] Created StreamTranscriptionParams:");
    print("  sessionId=${params.sessionId}");
    print("  languageCode=${params.languageCode}");

    try {
      print("[CONTROLLER_DEBUG] Calling _streamTranscription");
      final transcriptionStream = _streamTranscription(params);
      print("[CONTROLLER_DEBUG] StreamTranscription started");

      _transcriptionSubscription = transcriptionStream.listen(
        (result) {
          print("[CONTROLLER_DEBUG] Received transcription result: $result");
          result.fold(
            (failure) {
              print(
                "[CONTROLLER_DEBUG] Transcription failure: ${failure.message}",
              );
              _errorMessage = failure.message;
              _isListening = false;
              notifyListeners();
            },
            (transcript) {
              print(
                "[CONTROLLER_DEBUG] Transcription success: '${transcript.text}' (final: ${transcript.isFinal})",
              );
              if (transcript.isFinal) {
                if (transcript.text.trim().isNotEmpty) {
                  _transcripts.add(transcript);
                  _partialTranscript = '';
                  print("[CONTROLLER_DEBUG] Final transcript added");
                }
              } else {
                _partialTranscript = transcript.text;
                print("[CONTROLLER_DEBUG] Partial transcript updated");
              }
              notifyListeners();
            },
          );
        },
        onError: (error) {
          print("[CONTROLLER_DEBUG] Transcription stream error: $error");

          if (error is MicrophonePermissionException) {
            _errorMessage =
                'Microphone permission is required. Please enable it in settings.';
          } else {
            _errorMessage = 'Error in transcription: ${error.toString()}';
          }

          _isListening = false;
          notifyListeners();
          _logger.e('Error in transcription stream', error: error);
        },
        onDone: () {
          print("[CONTROLLER_DEBUG] Transcription stream done");
          _isListening = false;
          notifyListeners();
        },
      );

      print("[CONTROLLER_DEBUG] Subscription successfully set up");
      return true;
    } catch (e, stacktrace) {
      print(
        "[CONTROLLER_DEBUG] Exception caught while starting transcription: $e",
      );
      print("[CONTROLLER_DEBUG] Stacktrace: $stacktrace");
      _logger.e('Failed to start listening', error: e, stackTrace: stacktrace);

      if (e is MicrophonePermissionException) {
        _errorMessage =
            'Microphone permission is required. Please enable it in settings.';
      } else {
        _errorMessage =
            'Failed to start speech recognition. Please check your internet connection and try again.';
      }

      _isListening = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop listening for transcription
  Future<void> stopListening() async {
    print(
      "[CONTROLLER_DEBUG] stopListening called, _isListening=$_isListening",
    );
    if (!_isListening) return;

    try {
      print("[CONTROLLER_DEBUG] Cancelling subscription");
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;

      print("[CONTROLLER_DEBUG] Stopping stream transcription");
      await _streamTranscription.stop();

      _isListening = false;
      notifyListeners();
      print("[CONTROLLER_DEBUG] Listening stopped successfully");
    } catch (e, stacktrace) {
      print("[CONTROLLER_DEBUG] Exception when stopping listening: $e");
      _logger.e('Failed to stop listening', error: e, stackTrace: stacktrace);
    }
  }

  /// Clear all transcripts
  void clearTranscripts() {
    print("[CONTROLLER_DEBUG] clearTranscripts called");
    _transcripts.clear();
    _partialTranscript = '';
    notifyListeners();
    print("[CONTROLLER_DEBUG] Transcripts cleared");
  }

  @override
  void dispose() {
    print("[CONTROLLER_DEBUG] dispose called");
    stopListening();
    _transcriptionSubscription?.cancel();
    print("[CONTROLLER_DEBUG] Controller disposed");
    super.dispose();
  }
}
