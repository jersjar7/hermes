// lib/core/hermes_engine/usecases/start_session.dart

import 'package:hermes/core/hermes_engine/state/hermes_event.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import '../utils/log.dart';

/// Use case to start or join a Hermes session, handling permissions and connections.
class StartSessionUseCase {
  final IPermissionService permissionService;
  final ISpeechToTextService sttService;
  final ISessionService sessionService;
  final ISocketService socketService;
  final HermesLogger logger;

  StartSessionUseCase({
    required this.permissionService,
    required this.sttService,
    required this.sessionService,
    required this.socketService,
    required this.logger,
  });

  /// Executes the start/join flow:
  /// - If user is speaker: request mic, initialize STT, start session and socket.
  /// - If user is audience: join session on socket.
  /// Throws [EngineErrorOccurred] on failures.
  Future<void> execute({
    required bool isSpeaker,
    required String languageCode,
    String? sessionCode,
  }) async {
    if (isSpeaker) {
      await _startSpeakerSession(languageCode);
    } else {
      await _joinAudienceSession(sessionCode!);
    }
  }

  Future<void> _startSpeakerSession(String languageCode) async {
    try {
      // Step 1: Check and request microphone permission
      logger.info('🎤 Checking microphone permission...', tag: 'StartSession');
      print('🎤 [StartSession] Requesting microphone permission...');

      final granted = await permissionService.requestMicrophonePermission();
      if (!granted) {
        print('❌ [StartSession] Microphone permission denied');
        throw EngineErrorOccurred(
          'Microphone access is required for speech translation. '
          'Please enable microphone permissions in your device settings.',
        );
      }

      print('✅ [StartSession] Microphone permission granted');
      logger.info('✅ Microphone permission granted', tag: 'StartSession');

      // Step 2: Initialize speech-to-text
      logger.info(
        '🎙️ Initializing speech recognition...',
        tag: 'StartSession',
      );
      print('🎙️ [StartSession] Initializing STT service...');

      final sttReady = await sttService.initialize();
      if (!sttReady) {
        print('❌ [StartSession] STT initialization failed');
        throw EngineErrorOccurred(
          'Speech recognition is not available on this device. '
          'Please ensure your device supports speech recognition.',
        );
      }

      print('✅ [StartSession] STT service initialized successfully');
      logger.info('✅ Speech recognition ready', tag: 'StartSession');

      // Step 3: Start session
      logger.info('📱 Creating session...', tag: 'StartSession');
      print('📱 [StartSession] Starting session with language: $languageCode');

      await sessionService.startSession(languageCode: languageCode);
      final sessionId = sessionService.currentSession!.sessionId;

      print('✅ [StartSession] Session created with ID: $sessionId');
      logger.info('✅ Session created: $sessionId', tag: 'StartSession');

      // Step 4: Connect to WebSocket
      logger.info('🌐 Connecting to session...', tag: 'StartSession');
      print('🌐 [StartSession] Connecting socket for session: $sessionId');

      await socketService.connect(sessionId);

      print('✅ [StartSession] Successfully connected to session');
      logger.info('✅ Connected to session successfully', tag: 'StartSession');
    } catch (e, stackTrace) {
      print('💥 [StartSession] Speaker session failed: $e');
      logger.error(
        'Speaker session start failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'StartSession',
      );

      // Re-throw with context if it's not already an EngineErrorOccurred
      if (e is EngineErrorOccurred) {
        rethrow;
      } else {
        throw EngineErrorOccurred('Failed to start session: ${e.toString()}');
      }
    }
  }

  Future<void> _joinAudienceSession(String sessionCode) async {
    try {
      if (sessionCode.isEmpty) {
        throw EngineErrorOccurred('Session code is required to join a session');
      }

      logger.info('👥 Joining session as audience...', tag: 'StartSession');
      print('👥 [StartSession] Joining session: $sessionCode');

      await sessionService.joinSession(sessionCode);
      await socketService.connect(sessionCode);

      print('✅ [StartSession] Successfully joined session: $sessionCode');
      logger.info('✅ Joined session successfully', tag: 'StartSession');
    } catch (e, stackTrace) {
      print('💥 [StartSession] Join session failed: $e');
      logger.error(
        'Join session failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'StartSession',
      );

      if (e is EngineErrorOccurred) {
        rethrow;
      } else {
        throw EngineErrorOccurred('Failed to join session: ${e.toString()}');
      }
    }
  }
}
