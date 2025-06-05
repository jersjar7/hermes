// lib/core/hermes_engine/speaker/speaker_engine.dart
// STEP 3: Enhanced SpeakerEngine with pattern detection - ONLY sends confirmed sentences

import 'dart:async';

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

import '../state/hermes_session_state.dart';
import '../state/hermes_status.dart';
import '../usecases/start_session.dart';
import '../usecases/connectivity_handler.dart';
import '../utils/log.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service_impl.dart';
import 'package:hermes/core/services/speech_to_text/speech_result.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

/// 🎯 ENHANCED: SpeakerEngine that only sends pattern-confirmed complete sentences
class SpeakerEngine {
  final IPermissionService _permission;
  final ISpeechToTextService _stt;
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final HermesLogger _log;

  // Core state
  HermesSessionState _state = HermesSessionState.initial();
  StreamController<HermesSessionState>? _stateController;
  Stream<HermesSessionState> get stream =>
      _stateController?.stream ?? const Stream.empty();

  // Session management
  bool _isSessionActive = false;

  // 🆕 Pattern detection state tracking
  String _lastSentTranscript = "";
  DateTime _lastSentTimestamp = DateTime.now();

  // Audience tracking
  int _audienceCount = 0;
  Map<String, int> _languageDistribution = {};

  // Socket subscription
  StreamSubscription<SocketEvent>? _socketSubscription;

  // Infrastructure
  late final StartSessionUseCase _startUseCase;
  late final ConnectivityHandlerUseCase _connHandler;

  SpeakerEngine({
    required IPermissionService permission,
    required ISpeechToTextService stt,
    required ITranslationService translator,
    required ITextToSpeechService tts,
    required ISessionService session,
    required ISocketService socket,
    required IConnectivityService connectivity,
    required ILoggerService logger,
  }) : _permission = permission,
       _stt = stt,
       _session = session,
       _socket = socket,
       _connectivity = connectivity,
       _log = HermesLogger(logger) {
    _ensureStateController();

    _startUseCase = StartSessionUseCase(
      permissionService: _permission,
      sttService: _stt,
      sessionService: _session,
      socketService: _socket,
      logger: _log,
    );
    _connHandler = ConnectivityHandlerUseCase(
      connectivityService: _connectivity,
      logger: _log,
    );
  }

  void _ensureStateController() {
    if (_stateController == null || _stateController!.isClosed) {
      _stateController?.close();
      _stateController = StreamController<HermesSessionState>.broadcast();
      print('🔄 [SpeakerEngine] Created new state controller');
    }
  }

  /// Starts speaker flow with PATTERN-BASED sentence detection
  Future<void> start({required String languageCode}) async {
    print(
      '🎤 [SpeakerEngine] Starting speaker session with PATTERN DETECTION...',
    );

    try {
      _ensureStateController();
      _emit(_state.copyWith(status: HermesStatus.buffering));

      await _startUseCase.execute(isSpeaker: true, languageCode: languageCode);
      _listenToSocketEvents();
      _connHandler.startMonitoring(
        onOffline: _handleOffline,
        onOnline: _handleOnline,
      );

      _isSessionActive = true;
      _startListening();
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Failed to start session: $e');
      _log.error(
        'Speaker session start failed',
        error: e,
        stackTrace: stackTrace,
      );
      _emit(
        _state.copyWith(
          status: HermesStatus.error,
          errorMessage: 'Failed to start session: $e',
        ),
      );
    }
  }

  void _listenToSocketEvents() {
    _socketSubscription?.cancel();
    _socketSubscription = _socket.onEvent.listen((event) {
      if (event is AudienceUpdateEvent) {
        _handleAudienceUpdate(event);
      } else if (event is SessionJoinEvent) {
        print(
          '👥 [SpeakerEngine] User joined: ${event.userId} (${event.language})',
        );
      } else if (event is SessionLeaveEvent) {
        print('👋 [SpeakerEngine] User left: ${event.userId}');
      }
    });
  }

  void _handleAudienceUpdate(AudienceUpdateEvent event) {
    print(
      '👥 [SpeakerEngine] Audience update: ${event.totalListeners} listeners',
    );
    print('   Languages: ${event.languageDistribution}');

    _audienceCount = event.totalListeners;
    _languageDistribution = event.languageDistribution;

    _emit(
      _state.copyWith(
        audienceCount: _audienceCount,
        languageDistribution: _languageDistribution,
      ),
    );
  }

  void _startListening() {
    if (!_isSessionActive) return;

    print('🎤 [SpeakerEngine] Starting PATTERN-BASED continuous listening...');
    _emit(_state.copyWith(status: HermesStatus.listening));

    // 🎯 CRITICAL: Check if we have the enhanced STT service
    if (_stt is SpeechToTextServiceImpl) {
      print('✅ [SpeakerEngine] Using ENHANCED pattern-based STT service');
      // Use the new pattern-based listening method
      (_stt).startPatternBasedListening(
        onPartialResult: _handlePartialResult,
        onConfirmedSentence: _handleConfirmedSentence,
        onError: _handleSpeechError,
      );
    } else {
      print('⚠️ [SpeakerEngine] Using fallback STT service');
      // Fallback to regular listening for other implementations
      _stt.startListening(
        onResult: _handleFallbackSpeechResult,
        onError: _handleSpeechError,
      );
    }
  }

  /// 🆕 NEW: Handle partial results (for UI updates only)
  void _handlePartialResult(SpeechResult result) async {
    if (!_isSessionActive) {
      print('🚫 [SpeakerEngine] Ignoring partial result - session inactive');
      return;
    }

    print('📝 [SpeakerEngine] Partial result: "${result.transcript}"');

    // Always update UI with latest transcript for real-time feedback
    _emit(
      _state.copyWith(
        status: HermesStatus.listening,
        lastTranscript: result.transcript,
      ),
    );
  }

  /// 🎯 CRITICAL: Handle pattern-confirmed complete sentences
  void _handleConfirmedSentence(SpeechResult result) async {
    if (!_isSessionActive) {
      print(
        '🚫 [SpeakerEngine] Ignoring confirmed sentence - session inactive',
      );
      return;
    }

    print(
      '🎯 [SpeakerEngine] ✅ PATTERN CONFIRMED SENTENCE: "${result.transcript}"',
    );

    // Update UI to show we're processing
    _emit(
      _state.copyWith(
        status: HermesStatus.translating,
        lastTranscript: result.transcript,
      ),
    );

    // Send the confirmed complete sentence to audience
    await _sendConfirmedSentence(result.transcript, 'pattern-confirmed');

    // Return to listening state
    if (_isSessionActive) {
      _emit(_state.copyWith(status: HermesStatus.listening));
    }
  }

  /// 🆕 FALLBACK: Handle speech results from regular STT service
  void _handleFallbackSpeechResult(SpeechResult result) async {
    if (!_isSessionActive) {
      print('🚫 [SpeakerEngine] Ignoring speech result - session inactive');
      return;
    }

    print(
      '📝 [SpeakerEngine] Fallback speech result: "${result.transcript}" (final: ${result.isFinal})',
    );

    // Always update UI
    _emit(
      _state.copyWith(
        status:
            result.isFinal ? HermesStatus.translating : HermesStatus.listening,
        lastTranscript: result.transcript,
      ),
    );

    // For fallback mode, use Dart-side pattern detection
    if (result.isFinal) {
      print('🔍 [SpeakerEngine] Fallback mode - using Dart pattern detection');

      if (_isDartPatternComplete(result.transcript)) {
        print('🎯 [SpeakerEngine] Dart pattern detected complete sentence');
        await _sendConfirmedSentence(result.transcript, 'dart-pattern');
      } else {
        print(
          '🚫 [SpeakerEngine] Dart pattern: sentence not complete, not sending',
        );
      }
    }

    // Continue listening
    if (_isSessionActive) {
      _emit(_state.copyWith(status: HermesStatus.listening));
    }
  }

  void _handleSpeechError(Exception error) {
    print('⚠️ [SpeakerEngine] Speech error: $error');

    if (!_isSessionActive) {
      print('🚫 [SpeakerEngine] Ignoring speech error - session inactive');
      return;
    }

    _emit(_state.copyWith(status: HermesStatus.listening, errorMessage: null));
  }

  /// 🆕 BACKUP: Simple Dart-side pattern detection as fallback
  bool _isDartPatternComplete(String text) {
    final cleanText = text.trim();

    // Must be reasonable length
    if (cleanText.length < 12) return false;

    // Check for clear sentence endings
    if (cleanText.endsWith('.') ||
        cleanText.endsWith('!') ||
        cleanText.endsWith('?')) {
      // Make sure it's not an abbreviation
      if (!_isLikelyAbbreviation(cleanText)) {
        return true;
      }
    }

    // Check for natural transitions indicating complete thoughts
    final transitionPatterns = [
      RegExp(
        r'[.!?]\s+(However|Nevertheless|Therefore|Meanwhile|Furthermore)\s+\w+',
      ),
      RegExp(r'[.!?]\s+(And then|But then|So then|After that)\s+\w+'),
    ];

    for (final pattern in transitionPatterns) {
      if (pattern.hasMatch(cleanText)) {
        return true;
      }
    }

    return false;
  }

  bool _isLikelyAbbreviation(String text) {
    final commonAbbreviations = [
      'Dr.',
      'Mr.',
      'Mrs.',
      'Ms.',
      'Prof.',
      'Inc.',
      'Corp.',
      'Ltd.',
      'etc.',
      'vs.',
      'e.g.',
      'i.e.',
      'U.S.',
      'U.K.',
    ];

    for (final abbrev in commonAbbreviations) {
      if (text.toLowerCase().endsWith(abbrev.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// 🆕 Method to send confirmed complete sentences (called by pattern detector)
  Future<void> _sendConfirmedSentence(String transcript, String reason) async {
    if (!_isSessionActive) {
      print('🚫 [SpeakerEngine] Cannot send - session inactive');
      return;
    }

    // Prevent duplicates
    final now = DateTime.now();
    final timeSinceLastSent = now.difference(_lastSentTimestamp).inSeconds;

    if (transcript == _lastSentTranscript && timeSinceLastSent < 2) {
      print(
        '🔄 [SpeakerEngine] Skipping duplicate sentence: "${transcript.substring(0, transcript.length.clamp(0, 30))}..."',
      );
      return;
    }

    print(
      '🎯 [SpeakerEngine] ✅ SENDING CONFIRMED COMPLETE SENTENCE: "${transcript.substring(0, transcript.length.clamp(0, 50))}..." (reason: $reason)',
    );

    try {
      await _socket.send(
        TranscriptEvent(
          sessionId: _session.currentSession!.sessionId,
          text: transcript,
          isFinal: true,
        ),
      );

      _lastSentTranscript = transcript;
      _lastSentTimestamp = now;

      print('✅ [SpeakerEngine] Confirmed sentence sent to audience');
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Failed to send confirmed sentence: $e');
      _log.error(
        'Failed to send confirmed sentence',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleOffline() {
    print('📵 [SpeakerEngine] Going offline - pausing session');
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  void _handleOnline() {
    print('📶 [SpeakerEngine] Coming online - resuming session');
    if (_isSessionActive) {
      _startListening();
    }
  }

  /// 🆕 PUBLIC METHOD: Call this from pattern detector results
  /// This should be called when the Swift pattern detector confirms a complete sentence
  Future<void> sendPatternConfirmedSentence(
    String transcript,
    String reason,
  ) async {
    await _sendConfirmedSentence(transcript, reason);
  }

  /// Enhanced stop method with proper cleanup
  Future<void> stop() async {
    print('🛑 [SpeakerEngine] Stopping speaker session...');

    _isSessionActive = false;

    try {
      await _stt.stopListening();
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('⚠️ [SpeakerEngine] Error stopping STT: $e');
    }

    _socketSubscription?.cancel();
    _socketSubscription = null;
    _connHandler.dispose();

    try {
      await _socket.disconnect();
    } catch (e) {
      print('⚠️ [SpeakerEngine] Error disconnecting socket: $e');
    }

    _audienceCount = 0;
    _audienceCount = 0;
    _languageDistribution = {};
    _lastSentTranscript = "";

    _emit(_state.copyWith(status: HermesStatus.idle));
    await Future.delayed(const Duration(milliseconds: 50));
    print('✅ [SpeakerEngine] Speaker session stopped');
  }

  Future<void> pause() async {
    print('⏸️ [SpeakerEngine] Pausing session...');
    await _stt.stopListening();
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  Future<void> resume() async {
    print('▶️ [SpeakerEngine] Resuming session...');
    if (_isSessionActive) {
      _startListening();
    }
  }

  int get audienceCount => _audienceCount;
  Map<String, int> get languageDistribution =>
      Map.unmodifiable(_languageDistribution);

  void _emit(HermesSessionState s) {
    if (_stateController != null && !_stateController!.isClosed) {
      _state = s;
      _stateController!.add(s);
      print('🔄 [SpeakerEngine] State: ${s.status}');
    } else {
      print('⚠️ [SpeakerEngine] Cannot emit state - controller closed or null');
    }
  }

  void dispose() {
    print('🗑️ [SpeakerEngine] Disposing speaker engine...');

    _isSessionActive = false;
    _stt.dispose();
    _socketSubscription?.cancel();
    _connHandler.dispose();

    if (_stateController != null && !_stateController!.isClosed) {
      _stateController!.close();
    }
    _stateController = null;

    print('✅ [SpeakerEngine] Speaker engine disposed');
  }
}
