// lib/features/translation/presentation/controllers/speaker_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';
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
  bool _isPaused = false;
  String _errorMessage = '';
  PermissionStatus? _permissionStatus;
  Session? _activeSession;
  final List<Transcript> _transcripts = [];
  String _partialTranscript = '';
  bool _hasPermission = false;
  bool _isInitializing = false; // New flag to track initialization
  DateTime? _startListeningTime; // Track when listening started

  /// Creates a new [SpeakerController]
  SpeakerController(this._streamTranscription, this._logger) {
    _logger.d("[CONTROLLER_DEBUG] SpeakerController initialized");
  }

  /// Whether the speaker is currently listening
  bool get isListening => _isListening;

  /// Whether the listening is paused
  bool get isPaused => _isPaused;

  /// Error message, if any
  String get errorMessage => _errorMessage;

  /// Get the current permission status
  PermissionStatus? get permissionStatus => _permissionStatus;

  /// Check if permission error
  bool get isPermissionError =>
      _permissionStatus != null && !_permissionStatus!.isGranted;

  /// Active session
  Session? get activeSession => _activeSession;

  /// List of transcripts
  List<Transcript> get transcripts => List.unmodifiable(_transcripts);

  /// Current partial transcript
  String get partialTranscript => _partialTranscript;

  /// Whether controller is initializing audio
  bool get isInitializing => _isInitializing;

  /// Set the active session
  void setActiveSession(Session session) {
    _logger.d("[CONTROLLER_DEBUG] Setting active session: ${session.id}");
    _activeSession = session;

    // Proactively check for microphone permission
    _checkMicrophonePermission().then((permissionResult) {
      final (hasPermission, status) = permissionResult;
      _hasPermission = hasPermission;
      _permissionStatus = status;

      if (!hasPermission) {
        _errorMessage =
            'Microphone permission is required. Please grant it in settings.';
      }
      notifyListeners();
    });
  }

  /// Check if microphone permission is granted
  /// Returns a tuple with (hasPermission, permissionStatus)
  Future<(bool, PermissionStatus)> _checkMicrophonePermission() async {
    _logger.d("[CONTROLLER_DEBUG] Checking microphone permission");
    final status = await Permission.microphone.status;

    _logger.d("[CONTROLLER_DEBUG] Current permission status: $status");

    if (status.isGranted) {
      return (true, status);
    }

    if (status.isDenied) {
      final requestResult = await Permission.microphone.request();
      return (requestResult.isGranted, requestResult);
    }

    return (false, status);
  }

  /// Start listening for transcription
  Future<bool> startListening() async {
    _logger.d("[CONTROLLER_DEBUG] startListening called");
    _logger.d(
      "[CONTROLLER_DEBUG] State: _isListening=$_isListening, _activeSession=${_activeSession != null}, _isInitializing=$_isInitializing",
    );

    // Prevent multiple initialization attempts
    if (_isListening || _activeSession == null || _isInitializing) {
      _logger.d(
        "[CONTROLLER_DEBUG] Cannot start listening: ${_isListening
            ? 'already listening'
            : _isInitializing
            ? 'initializing'
            : 'no active session'}",
      );
      return false;
    }

    _errorMessage = '';
    _isInitializing = true;
    notifyListeners();

    // Check microphone permission
    if (!_hasPermission) {
      _logger.d("[CONTROLLER_DEBUG] Checking microphone permission");
      final permissionResult = await _checkMicrophonePermission();
      _hasPermission = permissionResult.$1;
      _permissionStatus = permissionResult.$2;

      if (!_hasPermission) {
        _logger.d(
          "[CONTROLLER_DEBUG] Microphone permission not granted: $_permissionStatus",
        );
        _errorMessage =
            'Microphone permission is required. Please grant it in settings.';
        _isInitializing = false;
        notifyListeners();
        return false;
      }
    }

    // Start listening timestamp
    _startListeningTime = DateTime.now();

    // Set state to listening
    _isListening = true;
    _isPaused = false;
    _partialTranscript = '';
    _isInitializing = false;
    notifyListeners();

    _logger.d(
      "[CONTROLLER_DEBUG] Set state to listening and notified listeners",
    );

    final params = StreamTranscriptionParams(
      sessionId: _activeSession!.id,
      languageCode: _activeSession!.sourceLanguage,
    );

    _logger.d("[CONTROLLER_DEBUG] Created StreamTranscriptionParams:");
    _logger.d("  sessionId=${params.sessionId}");
    _logger.d("  languageCode=${params.languageCode}");

    try {
      _logger.d("[CONTROLLER_DEBUG] Calling _streamTranscription with params");
      final transcriptionStream = _streamTranscription(params);
      _logger.d("[CONTROLLER_DEBUG] StreamTranscription started");

      _transcriptionSubscription = transcriptionStream.listen(
        (result) {
          final elapsed =
              DateTime.now().difference(_startListeningTime!).inMilliseconds;
          _logger.d(
            "[CONTROLLER_DEBUG] [+${elapsed}ms] Received transcription result",
          );

          result.fold(
            (failure) {
              _logger.d(
                "[CONTROLLER_DEBUG] [+${elapsed}ms] Transcription failure: ${failure.message}",
              );
              _errorMessage = failure.message;

              // Check if the error was due to permission issues
              if (failure is SpeechRecognitionFailure &&
                  failure.message.contains('permission')) {
                _checkMicrophonePermission().then((result) {
                  _permissionStatus = result.$2;
                  notifyListeners();
                });
              }

              _isListening = false;
              _isPaused = false;
              notifyListeners();
            },
            (transcript) {
              if (!_isListening) return; // Skip if no longer listening

              _logger.d(
                "[CONTROLLER_DEBUG] [+${elapsed}ms] Transcription: '${transcript.text}' (final: ${transcript.isFinal})",
              );

              if (transcript.isFinal) {
                if (transcript.text.trim().isNotEmpty) {
                  _transcripts.add(transcript);
                  _partialTranscript = '';
                  _logger.d("[CONTROLLER_DEBUG] Final transcript added");
                }
              } else {
                _partialTranscript = transcript.text;
                _logger.d("[CONTROLLER_DEBUG] Partial transcript updated");
              }
              notifyListeners();
            },
          );
        },
        onError: (error) {
          final elapsed =
              _startListeningTime != null
                  ? DateTime.now()
                      .difference(_startListeningTime!)
                      .inMilliseconds
                  : 0;

          _logger.d(
            "[CONTROLLER_DEBUG] [+${elapsed}ms] Transcription stream error: $error",
          );

          if (error is MicrophonePermissionException) {
            _errorMessage =
                'Microphone permission is required. Please enable it in settings.';
            _hasPermission = false;
            _checkMicrophonePermission().then((result) {
              _permissionStatus = result.$2;
              notifyListeners();
            });
          } else {
            _errorMessage = 'Error in transcription: ${error.toString()}';
          }

          _isListening = false;
          _isPaused = false;
          notifyListeners();
          _logger.e('Error in transcription stream', error: error);
        },
        onDone: () {
          final elapsed =
              _startListeningTime != null
                  ? DateTime.now()
                      .difference(_startListeningTime!)
                      .inMilliseconds
                  : 0;

          _logger.d(
            "[CONTROLLER_DEBUG] [+${elapsed}ms] Transcription stream done",
          );
          _isListening = false;
          _isPaused = false;
          notifyListeners();
        },
      );

      _logger.d("[CONTROLLER_DEBUG] Subscription successfully set up");
      return true;
    } catch (e, stacktrace) {
      final elapsed =
          _startListeningTime != null
              ? DateTime.now().difference(_startListeningTime!).inMilliseconds
              : 0;

      _logger.d(
        "[CONTROLLER_DEBUG] [+${elapsed}ms] Exception caught while starting transcription: $e",
      );
      _logger.d("[CONTROLLER_DEBUG] Stacktrace: $stacktrace");
      _logger.e('Failed to start listening', error: e, stackTrace: stacktrace);

      if (e is MicrophonePermissionException) {
        _errorMessage =
            'Microphone permission is required. Please enable it in settings.';
        _hasPermission = false;
        _checkMicrophonePermission().then((result) {
          _permissionStatus = result.$2;
          notifyListeners();
        });
      } else {
        _errorMessage = 'Failed to start speech recognition: ${e.toString()}';
      }

      _isListening = false;
      _isPaused = false;
      _isInitializing = false;
      notifyListeners();
      return false;
    }
  }

  /// Pause listening for transcription
  Future<bool> pauseListening() async {
    _logger.d(
      "[CONTROLLER_DEBUG] pauseListening called, _isListening=$_isListening, _isPaused=$_isPaused",
    );
    if (!_isListening || _isPaused) return false;

    try {
      _logger.d("[CONTROLLER_DEBUG] Calling _streamTranscription.pause()");
      final result = await _streamTranscription.pause();

      return result.fold(
        (failure) {
          _logger.d("[CONTROLLER_DEBUG] Pause failure: ${failure.message}");
          _errorMessage = failure.message;
          notifyListeners();
          return false;
        },
        (_) {
          _logger.d("[CONTROLLER_DEBUG] Pause successful");
          _isPaused = true;
          notifyListeners();
          return true;
        },
      );
    } catch (e, stacktrace) {
      _logger.d("[CONTROLLER_DEBUG] Exception when pausing: $e");
      _logger.e('Failed to pause listening', error: e, stackTrace: stacktrace);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Resume listening for transcription
  Future<bool> resumeListening() async {
    _logger.d(
      "[CONTROLLER_DEBUG] resumeListening called, _isListening=$_isListening, _isPaused=$_isPaused",
    );
    if (!_isListening || !_isPaused) return false;

    try {
      _logger.d("[CONTROLLER_DEBUG] Calling _streamTranscription.resume()");
      final result = await _streamTranscription.resume();

      return result.fold(
        (failure) {
          _logger.d("[CONTROLLER_DEBUG] Resume failure: ${failure.message}");
          _errorMessage = failure.message;
          notifyListeners();
          return false;
        },
        (_) {
          _logger.d("[CONTROLLER_DEBUG] Resume successful");
          _isPaused = false;
          notifyListeners();
          return true;
        },
      );
    } catch (e, stacktrace) {
      _logger.d("[CONTROLLER_DEBUG] Exception when resuming: $e");
      _logger.e('Failed to resume listening', error: e, stackTrace: stacktrace);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Stop listening for transcription
  Future<void> stopListening() async {
    _logger.d(
      "[CONTROLLER_DEBUG] stopListening called, _isListening=$_isListening, _isPaused=$_isPaused",
    );
    if (!_isListening) return;

    try {
      _logger.d("[CONTROLLER_DEBUG] Cancelling subscription");
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;

      _logger.d("[CONTROLLER_DEBUG] Stopping stream transcription");
      await _streamTranscription.stop();

      _isListening = false;
      _isPaused = false;
      notifyListeners();
      _logger.d("[CONTROLLER_DEBUG] Listening stopped successfully");
    } catch (e, stacktrace) {
      _logger.d("[CONTROLLER_DEBUG] Exception when stopping listening: $e");
      _logger.e('Failed to stop listening', error: e, stackTrace: stacktrace);
    }
  }

  /// Clear all transcripts
  void clearTranscripts() {
    _logger.d("[CONTROLLER_DEBUG] clearTranscripts called");
    _transcripts.clear();
    _partialTranscript = '';
    notifyListeners();
    _logger.d("[CONTROLLER_DEBUG] Transcripts cleared");
  }

  /// Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.d("[CONTROLLER_DEBUG] dispose called");
    _cleanupResources();
    super.dispose();
  }

  /// Stream that emits whenever the controller changes state
  Stream<void> get listenerStream => _listenerStreamController.stream;

  // Create a stream controller for notifying listeners of state changes
  final StreamController<void> _listenerStreamController =
      StreamController<void>.broadcast();

  @override
  void notifyListeners() {
    super.notifyListeners();
    // Also notify through stream
    if (!_listenerStreamController.isClosed) {
      _listenerStreamController.add(null);
    }
  }

  /// Clean up resources
  Future<void> _cleanupResources() async {
    try {
      // Stop listening first to prevent new data from coming in
      if (_isListening) {
        await stopListening();
      }

      // Ensure subscription is properly canceled
      if (_transcriptionSubscription != null) {
        await _transcriptionSubscription?.cancel();
        _transcriptionSubscription = null;
        _logger.d("[CONTROLLER_DEBUG] Transcription subscription canceled");
      }

      // Explicitly mark as not listening and not paused
      _isListening = false;
      _isPaused = false;
      _isInitializing = false;

      // Close stream controller
      await _listenerStreamController.close();
    } catch (e, stacktrace) {
      _logger.e(
        'Error cleaning up resources',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }
}
