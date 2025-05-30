// lib/dev/try_hermes_root_engine_audience.dart

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/hermes_engine/hermes_engine.dart';
import 'package:hermes/core/hermes_engine/config/hermes_config.dart';
import 'package:hermes/core/hermes_engine/state/hermes_session_state.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/hermes_engine/speaker/speaker_engine.dart';
import 'package:hermes/core/hermes_engine/audience/audience_engine.dart';
import 'package:hermes/core/hermes_engine/usecases/playback_control.dart';
import 'package:hermes/core/hermes_engine/buffer/translation_buffer.dart';
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

  // Core services
  final permSvc = getIt<IPermissionService>();
  final sttSvc = getIt<ISpeechToTextService>();
  final transSvc = getIt<ITranslationService>();
  final ttsSvc = getIt<ITextToSpeechService>();
  final connSvc = getIt<IConnectivityService>();
  final sessSvc = getIt<ISessionService>();
  final sockSvc = getIt<ISocketService>();
  final logSvc = getIt<ILoggerService>();

  // Shared buffer
  final sharedBuffer = TranslationBuffer();

  // Playback use-case uses the same buffer
  final hermesLog = HermesLogger(logSvc);
  final playbackCtrl = PlaybackControlUseCase(
    ttsService: ttsSvc,
    buffer: sharedBuffer,
    logger: hermesLog,
  );
  final countdownTimer = CountdownTimer();

  // Sub‐engines, both share the same buffer
  final speakerEngine = SpeakerEngine(
    permission: permSvc,
    stt: sttSvc,
    translator: transSvc,
    tts: ttsSvc,
    session: sessSvc,
    socket: sockSvc,
    connectivity: connSvc,
    logger: logSvc,
  );

  final audienceEngine = AudienceEngine(
    buffer: sharedBuffer,
    session: sessSvc,
    socket: sockSvc,
    connectivity: connSvc,
    logger: logSvc,
  );

  // Root engine
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

  // Kick off audience path
  const sessionCode = 'ROOT01';
  await engine.joinSession(sessionCode);

  // Emit three translations
  for (var i = 1; i <= 3; i++) {
    final text = 'Root Segment #$i';
    print('📡 Emitting TranslationEvent: "$text"');
    sockSvc.send(
      TranslationEvent(
        sessionId: sessionCode,
        translatedText: text,
        targetLanguage: 'en',
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));
  }

  final wait = kInitialBufferCountdownSeconds + 2;
  print('⌛ Waiting $wait seconds for countdown & playback...');
  await Future.delayed(Duration(seconds: wait));

  await engine.stop();
  await sub.cancel();
  print('✅ Root audience engine test complete.');
}
