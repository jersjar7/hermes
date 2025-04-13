// lib/features/session/presentation/controllers/active_session_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hermes/config/env.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/usecases/end_session.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/presentation/controllers/speaker_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_service.dart';

/// UI state for the active session page
enum SessionViewState {
  /// Before speaking has started
  preSpeaking,

  /// While speaking is active
  speaking,

  /// Error state
  error,
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
  String? _errorDetails; // Added for more detailed error reporting
  int _listenerCount = 0;
  bool _hasCheckedPermission = false;
  bool _showTranscription = true;
  int _errorCount = 0; // Track error occurrences
  bool _apiConnected = false; // Track API connectivity status
  String _apiStatus = "Unknown"; // Store API status for UI
  DateTime? _streamStartTime; // When streaming started
  bool _isTestingMic = false; // Flag for microphone test
  bool _isTestingApi = false; // Flag for API test
  bool _showDiagnostics = false; // Whether to show diagnostics view

  // ADDED: Track if controller is disposed
  final bool _isDisposed = false;

  // Timers and subscriptions
  Timer? listenerUpdateTimer;
  StreamSubscription? sessionSubscription;
  StreamSubscription? speakerControllerSubscription;

  // Getters
  Session get session => _session;
  SessionViewState get viewState => _viewState;
  bool get isEnding => _isEnding;
  String? get errorMessage => _errorMessage;
  String? get errorDetails => _errorDetails;
  int get listenerCount => _listenerCount;
  bool get hasCheckedPermission => _hasCheckedPermission;
  bool get showTranscription => _showTranscription;
  int get errorCount => _errorCount;
  bool get apiConnected => _apiConnected;
  String get apiStatus => _apiStatus;
  bool get showDiagnostics => _showDiagnostics;

  // Stream time in milliseconds
  int get streamTimeMs =>
      _streamStartTime != null
          ? DateTime.now().difference(_streamStartTime!).inMilliseconds
          : 0;

  // Check if error is related to permissions
  bool get isPermissionError =>
      _speakerController.permissionStatus != null &&
      !_speakerController.permissionStatus!.isGranted;

  // Speaker controller state shortcuts
  bool get isListening => _speakerController.isListening;
  bool get isPaused => _speakerController.isPaused;
  bool get isInitializing => _speakerController.isInitializing;
  List<Transcript> get transcripts => _speakerController.transcripts;
  PermissionStatus? get permissionStatus => _speakerController.permissionStatus;

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

  /// Toggle showing the diagnostics view
  void toggleDiagnostics() {
    _showDiagnostics = !_showDiagnostics;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Test the microphone functionality
  Future<bool> testMicrophone() async {
    if (_isTestingMic) return false;

    _isTestingMic = true;
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      _logger.d("[TEST_MIC] Starting microphone test");
      final result = await _speakerController.testMicrophone();
      _logger.d("[TEST_MIC] Microphone test result: $result");

      _isTestingMic = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return result;
    } catch (e) {
      _logger.e("[TEST_MIC] Microphone test failed with error", error: e);
      _isTestingMic = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return false;
    }
  }

  /// Test the API connection
  Future<bool> testApiConnection() async {
    if (_isTestingApi) return false;

    _isTestingApi = true;
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      _logger.d("[TEST_API] Testing API connection");

      // Use a minimal API request to test connectivity
      final uri = Uri.https(
        'speech.googleapis.com',
        'v1p1beta1/speech:recognize',
        {'key': Env.googleCloudApiKey},
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              _logger.d("[TEST_API] API request timed out");
              return http.Response('Timeout', 408);
            },
          );

      _logger.d("[TEST_API] API test response: ${response.statusCode}");

      // Even an auth error (401/403) confirms the API is reachable
      final success =
          response.statusCode != 404 &&
          response.statusCode != 500 &&
          response.statusCode != 408;

      _apiConnected = success;
      _apiStatus = success ? "Connected" : "Disconnected";

      _isTestingApi = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.e("[TEST_API] API connection test failed", error: e);
      _apiConnected = false;
      _apiStatus = "Error";
      _isTestingApi = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return false;
    }
  }

  /// Initialize the controller
  void _initialize() {
    _logger.d("[SESSION_CONTROLLER] Initializing controller");
    _speakerController.setActiveSession(_session);
    _listenerCount = _session.listeners.length;
    _setupListenerUpdates();

    // Listen for changes in speaker controller state
    speakerControllerSubscription = _speakerController.listenerStream.listen(
      _handleSpeakerControllerUpdates,
    );

    // Check microphone permission
    _checkMicrophonePermission().then((hasPermission) {
      _hasCheckedPermission = true;
      _logger.d(
        "[SESSION_CONTROLLER] Initial permission check: $hasPermission",
      );
      if (!_isDisposed) {
        notifyListeners();
      }
    });

    // Test API connection
    testApiConnection().then((connected) {
      _logger.d("[SESSION_CONTROLLER] Initial API test: $connected");
    });
  }

  /// Handle updates from the speaker controller
  void _handleSpeakerControllerUpdates(void _) {
    _logger.d("[SESSION_CONTROLLER] Received update from speaker controller");

    // Update error message if present
    if (_speakerController.errorMessage.isNotEmpty) {
      _errorMessage = _speakerController.errorMessage;
      _errorCount++;

      // If we're speaking and got an error, transition to error state
      if (_viewState == SessionViewState.speaking &&
          !_speakerController.isListening) {
        _viewState = SessionViewState.error;
      }

      _logger.d(
        "[SESSION_CONTROLLER] Updated error: $_errorMessage (count: $_errorCount)",
      );
    }

    // Track when streaming starts
    if (_speakerController.isListening && _streamStartTime == null) {
      _streamStartTime = DateTime.now();
    }

    // Clear streaming start time when stopped
    if (!_speakerController.isListening) {
      _streamStartTime = null;
    }

    // Update view state based on speaker status
    if (_speakerController.isListening &&
        _viewState != SessionViewState.speaking) {
      _viewState = SessionViewState.speaking;
      _logger.d("[SESSION_CONTROLLER] Updated state to speaking");
    } else if (!_speakerController.isListening &&
        _viewState == SessionViewState.speaking) {
      // Only revert to preSpeaking if we didn't encounter an error
      if (_errorMessage == null || _errorMessage!.isEmpty) {
        _viewState = SessionViewState.preSpeaking;
        _logger.d("[SESSION_CONTROLLER] Updated state to preSpeaking");
      }
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Set up timer to periodically update listener count
  void _setupListenerUpdates() {
    // Update listener count periodically
    listenerUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _listenerCount = _session.listeners.length;
      if (!_isDisposed) {
        notifyListeners();
      }
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
      if (!_isDisposed) {
        notifyListeners();
      }
      return true;
    }

    if (status.isPermanentlyDenied) {
      return false;
    }

    if (status.isDenied || status.isRestricted) {
      final requestResult = await Permission.microphone.request();

      _hasCheckedPermission = true;
      if (!_isDisposed) {
        notifyListeners();
      }

      if (requestResult.isGranted) {
        return true;
      }

      return false;
    }

    return false;
  }

  /// Toggle listening state (start/stop)
  Future<bool> toggleListening() async {
    _logger.d(
      "[SESSION_CONTROLLER] toggleListening called, isListening=$isListening",
    );

    // Clear any previous error when attempting to start
    _errorMessage = null;
    _errorDetails = null;
    if (!_isDisposed) {
      notifyListeners();
    }

    if (isListening) {
      await _speakerController.stopListening();
      _viewState = SessionViewState.preSpeaking;
      _streamStartTime = null; // Clear the stream start time
      if (!_isDisposed) {
        notifyListeners();
      }
      return false;
    } else {
      // Check permission first
      final hasPermission = await _checkMicrophonePermission();

      if (hasPermission) {
        // Add more detailed logging
        _logger.d(
          "[SESSION_CONTROLLER] Permission granted, starting listening",
        );

        // Show initializing state immediately
        if (!_isDisposed) {
          notifyListeners();
        }

        // Set stream start time
        _streamStartTime = DateTime.now();
        _apiStatus = "Connecting";

        final success = await _speakerController.startListening();

        // Update API status based on result
        if (success) {
          _apiStatus = "Connected";
          _apiConnected = true;
        } else {
          _apiStatus = "Error";
          _apiConnected = false;
        }

        // Get any error from speaker controller
        if (_speakerController.errorMessage.isNotEmpty) {
          _errorMessage = _speakerController.errorMessage;
          _errorDetails =
              "Error code: STT-${DateTime.now().millisecondsSinceEpoch % 10000}";
          _viewState = SessionViewState.error;
        } else if (success) {
          _viewState = SessionViewState.speaking;
        }

        if (!_isDisposed) {
          notifyListeners();
        }
        return success;
      } else {
        _errorMessage = 'Microphone permission is required to use this feature';
        _viewState = SessionViewState.error;
        if (!_isDisposed) {
          notifyListeners();
        }
        return false;
      }
    }
  }

  /// Toggle pause/resume
  Future<bool> togglePauseResume() async {
    _logger.d(
      "[SESSION_CONTROLLER] togglePauseResume called, isPaused=$isPaused",
    );

    if (!isListening) return false;

    try {
      bool success;
      if (isPaused) {
        // Resume
        _logger.d("[SESSION_CONTROLLER] Attempting to resume");
        success = await _speakerController.resumeListening();
      } else {
        // Pause
        _logger.d("[SESSION_CONTROLLER] Attempting to pause");
        success = await _speakerController.pauseListening();
      }

      if (_speakerController.errorMessage.isNotEmpty) {
        _errorMessage = _speakerController.errorMessage;
      }

      if (!_isDisposed) {
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.e("[SESSION_CONTROLLER] Error in togglePauseResume", error: e);
      _errorMessage = e.toString();
      _errorDetails = "Failed to ${isPaused ? 'resume' : 'pause'} listening";
      if (!_isDisposed) {
        notifyListeners();
      }
      return false;
    }
  }

  /// End the session
  Future<bool> endSession() async {
    _logger.d("[SESSION_CONTROLLER] endSession called");
    _isEnding = true;
    _errorMessage = null;
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      // Stop listening if active
      if (isListening) {
        _logger.d(
          "[SESSION_CONTROLLER] Stopping active listening before ending session",
        );
        // Force-stop with timeout to ensure completion
        bool stoppedSuccessfully = false;
        try {
          await _speakerController.stopListening().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _logger.e(
                "[SESSION_CONTROLLER] Stopping listening timed out - forcing cleanup",
              );
              _completeSessionCleanup();
            },
          );
          stoppedSuccessfully = true;
        } catch (e) {
          _logger.e("[SESSION_CONTROLLER] Error stopping listening", error: e);
          _completeSessionCleanup();
        }

        _logger.d(
          "[SESSION_CONTROLLER] Listening stopped: $stoppedSuccessfully",
        );
      }

      _logger.d("[SESSION_CONTROLLER] Calling endSession use case");
      final params = EndSessionParams(sessionId: _session.id);
      final result = await _endSession(params);

      return result.fold(
        (failure) {
          _errorMessage = failure.message;
          _errorDetails = "Failed to end session on the server";
          _isEnding = false;
          _logger.e("[SESSION_CONTROLLER] End session failure", error: failure);
          if (!_isDisposed) {
            notifyListeners();
          }
          return false;
        },
        (endedSession) {
          _session = endedSession;
          _streamStartTime = null; // Clear stream start time
          _logger.d("[SESSION_CONTROLLER] Session ended successfully");
          if (!_isDisposed) {
            notifyListeners();
          }
          return true;
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _errorDetails = "Unexpected error when ending session";
      _isEnding = false;
      _logger.e("[SESSION_CONTROLLER] Error ending session", error: e);
      if (!_isDisposed) {
        notifyListeners();
      }
      return false;
    }
  }

  /// Helper method to completely clean up all resources when ending a session
  Future<void> _completeSessionCleanup() async {
    _logger.d("[SESSION_CONTROLLER] Performing complete session cleanup");
    try {
      // Force stop any active audio processing
      try {
        final sttService = GetIt.instance<SpeechToTextService>();
        await sttService.stopStreaming().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            _logger.d("[SESSION_CONTROLLER] STT stopStreaming timed out");
          },
        );
        _logger.d("[SESSION_CONTROLLER] STT service stopped");
      } catch (e) {
        _logger.e("[SESSION_CONTROLLER] Error stopping STT service", error: e);
      }

      // Clear all state
      _streamStartTime = null;
      _apiStatus = "Disconnected";
      _apiConnected = false;
    } catch (e) {
      _logger.e("[SESSION_CONTROLLER] Error during session cleanup", error: e);
    }
  }

  /// Retry after error
  Future<bool> retryAfterError() async {
    _logger.d("[SESSION_CONTROLLER] Retrying after error");

    // Clear error state
    _errorMessage = null;
    _errorDetails = null;
    _viewState = SessionViewState.preSpeaking;
    notifyListeners();

    // Attempt to start listening again
    return await toggleListening();
  }

  /// Toggle transcription visibility
  void toggleTranscriptionVisibility() {
    _showTranscription = !_showTranscription;
    _logger.d(
      "[SESSION_CONTROLLER] Toggled transcription visibility: $_showTranscription",
    );
    notifyListeners();
  }

  /// Get session duration
  Duration getSessionDuration() {
    return DateTime.now().difference(_session.createdAt);
  }
}
