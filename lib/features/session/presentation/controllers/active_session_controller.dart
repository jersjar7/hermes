// lib/features/session/presentation/controllers/active_session_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/usecases/end_session.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/presentation/controllers/speaker_controller.dart';
import 'package:permission_handler/permission_handler.dart';

/// UI state for the active session page
enum SessionViewState {
  /// Before speaking has started
  preSpeaking,

  /// While speaking is active
  speaking,
}

/// Controller to manage the UI state for an active session
class ActiveSessionController with ChangeNotifier {
  // Dependencies
  final SpeakerController _speakerController;
  final EndSession _endSession;
  final Logger _logger;

  // State properties
  Session _session;
  SessionViewState _viewState = SessionViewState.preSpeaking;
  bool _isEnding = false;
  String? _errorMessage;
  int _listenerCount = 0;
  bool _hasCheckedPermission = false;
  bool _showTranscription = true;

  // Timers and subscriptions
  Timer? _listenerUpdateTimer;
  StreamSubscription? _sessionSubscription;

  // Getters
  Session get session => _session;
  SessionViewState get viewState => _viewState;
  bool get isEnding => _isEnding;
  String? get errorMessage => _errorMessage;
  int get listenerCount => _listenerCount;
  bool get hasCheckedPermission => _hasCheckedPermission;
  bool get showTranscription => _showTranscription;

  // Speaker controller state shortcuts
  bool get isListening => _speakerController.isListening;
  bool get isPaused => _speakerController.isPaused;
  List<Transcript> get transcripts => _speakerController.transcripts;

  /// Creates a new [ActiveSessionController]
  ActiveSessionController({
    required SpeakerController speakerController,
    required EndSession endSession,
    required Logger logger,
    required Session session,
  }) : _speakerController = speakerController,
       _endSession = endSession,
       _logger = logger,
       _session = session {
    _initialize();
  }

  /// Initialize the controller
  void _initialize() {
    _speakerController.setActiveSession(_session);
    _listenerCount = _session.listeners.length;
    _setupListenerUpdates();

    // Check microphone permission
    _checkMicrophonePermission().then((hasPermission) {
      _hasCheckedPermission = hasPermission;
      notifyListeners();
    });
  }

  /// Set up timer to periodically update listener count
  void _setupListenerUpdates() {
    // Update listener count periodically
    _listenerUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _listenerCount = _session.listeners.length;
      notifyListeners();
    });

    // In a real implementation, you would subscribe to session updates
    // and update the UI when listeners join/leave
    // This would be implemented in the repository
  }

  /// Check microphone permission
  Future<bool> checkMicrophonePermission() async {
    return _checkMicrophonePermission();
  }

  /// Internal implementation of permission check
  Future<bool> _checkMicrophonePermission() async {
    _logger.d("[SESSION_CONTROLLER] Checking microphone permission");
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      _hasCheckedPermission = true;
      notifyListeners();
      return true;
    }

    if (status.isPermanentlyDenied) {
      return false;
    }

    if (status.isDenied || status.isRestricted) {
      final requestResult = await Permission.microphone.request();

      _hasCheckedPermission = true;
      notifyListeners();

      if (requestResult.isGranted) {
        return true;
      }

      return false;
    }

    return false;
  }

  /// Toggle listening state (start/stop)
  Future<bool> toggleListening() async {
    if (isListening) {
      await _speakerController.stopListening();
      _viewState = SessionViewState.preSpeaking;
      notifyListeners();
      return false;
    } else {
      // Check permission first
      final hasPermission = await _checkMicrophonePermission();

      if (hasPermission) {
        final success = await _speakerController.startListening();
        _errorMessage = _speakerController.errorMessage;

        if (success) {
          _viewState = SessionViewState.speaking;
        }

        notifyListeners();
        return success;
      } else {
        _errorMessage = 'Microphone permission is required to use this feature';
        notifyListeners();
        return false;
      }
    }
  }

  /// Toggle pause/resume
  Future<bool> togglePauseResume() async {
    if (!isListening) return false;

    try {
      bool success;
      if (isPaused) {
        // Resume
        success = await _speakerController.resumeListening();
      } else {
        // Pause
        success = await _speakerController.pauseListening();
      }

      _errorMessage = _speakerController.errorMessage;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// End the session
  Future<bool> endSession() async {
    _isEnding = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Stop listening if active
      if (isListening) {
        await _speakerController.stopListening();
      }

      final params = EndSessionParams(sessionId: _session.id);
      final result = await _endSession(params);

      return result.fold(
        (failure) {
          _errorMessage = failure.message;
          _isEnding = false;
          notifyListeners();
          return false;
        },
        (endedSession) {
          _session = endedSession;
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isEnding = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle transcription visibility
  void toggleTranscriptionVisibility() {
    _showTranscription = !_showTranscription;
    notifyListeners();
  }

  /// Get session duration
  Duration getSessionDuration() {
    return DateTime.now().difference(_session.createdAt);
  }

  @override
  void dispose() {
    _listenerUpdateTimer?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
