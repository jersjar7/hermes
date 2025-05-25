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
      logger.info('Requesting microphone permission', tag: 'StartSession');
      final granted = await permissionService.requestMicrophonePermission();
      if (!granted) {
        throw EngineErrorOccurred('Microphone permission denied');
      }

      logger.info('Initializing speech-to-text', tag: 'StartSession');
      final ok = await sttService.initialize();
      if (!ok) {
        throw EngineErrorOccurred('STT initialization failed');
      }

      logger.info('Starting session as speaker', tag: 'StartSession');
      await sessionService.startSession(languageCode: languageCode);
      final id = sessionService.currentSession!.sessionId;

      logger.info('Connecting socket for session $id', tag: 'StartSession');
      await socketService.connect(id);
    } else {
      final code = sessionCode;
      if (code == null) {
        throw EngineErrorOccurred('Session code is required to join');
      }
      logger.info('Joining session $code as audience', tag: 'StartSession');
      await sessionService.joinSession(code);
      await socketService.connect(code);
    }
  }
}
