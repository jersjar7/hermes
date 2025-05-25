// lib/dev/try_hermes_root_engine_audience.dart

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hermes/core/hermes_engine/buffer/translation_buffer.dart';
import 'dart:async';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/hermes_engine/hermes_engine.dart';
import 'package:hermes/core/hermes_engine/config/hermes_config.dart';
import 'package:hermes/core/hermes_engine/state/hermes_session_state.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/hermes_engine/speaker/speaker_engine.dart';
import 'package:hermes/core/hermes_engine/audience/audience_engine.dart';
import 'package:hermes/core/hermes_engine/usecases/playback_control.dart';
import 'package:hermes/core/hermes_engine/buffer/countdown_timer.dart';
import 'package:hermes/core/hermes_engine/utils/log.dart';

import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupServiceLocator();

  // Core services from GetIt
  final authService = getIt<IPermissionService>();
  final sttService = getIt<ISpeechToTextService>();
  final translationSvc = getIt<ITranslationService>();
  final ttsService = getIt<ITextToSpeechService>();
  final connectivitySvc = getIt<IConnectivityService>();
  final sessionSvc = getIt<ISessionService>();
  final socketSvc = getIt<ISocketService>();
  final loggerSvc = getIt<ILoggerService>();

  // Helpers
  final hermesLog = HermesLogger(loggerSvc);
  final playbackBuffer = TranslationBuffer();
  final playbackCtrl = PlaybackControlUseCase(
    ttsService: ttsService,
    buffer: playbackBuffer,
    logger: hermesLog,
  );
  final countdownTimer = CountdownTimer();

  // Sub‐engines
  final speakerEngine = SpeakerEngine(
    permission: authService,
    stt: sttService,
    translator: translationSvc,
    tts: ttsService,
    session: sessionSvc,
    socket: socketSvc,
    connectivity: connectivitySvc,
    logger: loggerSvc, // ← pass ILoggerService here
  );

  final audienceEngine = AudienceEngine(
    session: sessionSvc,
    socket: socketSvc,
    connectivity: connectivitySvc,
    logger: loggerSvc, // ← pass ILoggerService here
  );

  // Root HermioneEngine
  final engine = HermesEngine(
    speakerEngine: speakerEngine,
    audienceEngine: audienceEngine,
    playbackControl: playbackCtrl,
    countdown: countdownTimer,
  );

  print('▶︎ Starting ROOT HermesEngine in audience mode...');

  final sub = engine.stream.listen((HermesSessionState s) {
    print(
      '🔄 Engine state: ${s.status}'
      '  bufferSize=${s.buffer.length}'
      '  countdown=${s.countdownSeconds}',
    );
    if (s.status == HermesStatus.speaking) {
      print('✅ 🎉 ENTERED SPEAKING STATE!');
    }
  });

  // Kick off the audience path
  const sessionCode = 'ROOT01';
  await engine.joinSession(sessionCode);

  // Fire off three translation events
  for (var i = 1; i <= 3; i++) {
    final text = 'Root Segment #$i';
    print('📡 Emitting TranslationEvent: "$text"');
    socketSvc.send(
      TranslationEvent(
        sessionId: sessionCode,
        translatedText: text,
        targetLanguage: 'en',
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Wait long enough for countdown + speaking to start
  final wait = kInitialBufferCountdownSeconds + 2;
  print('⌛ Waiting $wait seconds for countdown & playback...');
  await Future.delayed(Duration(seconds: wait));

  // Clean up
  await engine.stop();
  await sub.cancel();
  print('✅ Root audience engine test complete.');
}
