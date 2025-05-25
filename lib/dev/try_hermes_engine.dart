// lib/dev/try_hermes_engine.dart

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/hermes_engine/hermes_engine.dart';
import 'package:hermes/core/hermes_engine/speaker/speaker_engine.dart';
import 'package:hermes/core/hermes_engine/audience/audience_engine.dart';
import 'package:hermes/core/hermes_engine/usecases/playback_control.dart';
import 'package:hermes/core/hermes_engine/buffer/countdown_timer.dart';
import 'package:hermes/core/hermes_engine/buffer/translation_buffer.dart';
import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/hermes_engine/config/hermes_config.dart';
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

  // Construct sub-engines and helpers manually
  final logger = getIt<ILoggerService>();
  final permission = getIt<IPermissionService>();
  final stt = getIt<ISpeechToTextService>();
  final translator = getIt<ITranslationService>();
  final tts = getIt<ITextToSpeechService>();
  final session = getIt<ISessionService>();
  final socket = getIt<ISocketService>();
  final connectivity = getIt<IConnectivityService>();

  final hermesLog = HermesLogger(logger);

  final speakerEngine = SpeakerEngine(
    permission: permission,
    stt: stt,
    translator: translator,
    tts: tts,
    session: session,
    socket: socket,
    connectivity: connectivity,
    logger: logger,
  );

  final audienceEngine = AudienceEngine(
    session: session,
    socket: socket,
    connectivity: connectivity,
    logger: logger,
  );

  // PlaybackControl needs its own buffer
  final playbackBuffer = TranslationBuffer();
  final playbackCtrl = PlaybackControlUseCase(
    ttsService: tts,
    buffer: playbackBuffer,
    logger: hermesLog,
  );

  final countdown = CountdownTimer();

  // Create the root engine
  final engine = HermesEngine(
    speakerEngine: speakerEngine,
    audienceEngine: audienceEngine,
    playbackControl: playbackCtrl,
    countdown: countdown,
  );

  // Listen to every state update
  final sub = engine.stream.listen((state) {
    print('🔄 Engine state: $state');
  });

  // --- Test Audience Flow ---
  print('▶︎ Starting audience flow...');
  const sessionCode = 'DEV01';
  await engine.joinSession(sessionCode);

  // Simulate incoming translation events
  socket.send(
    TranslationEvent(
      sessionId: sessionCode,
      translatedText: 'First test segment',
      targetLanguage: 'en',
    ),
  );
  await Future.delayed(Duration(seconds: kInitialBufferCountdownSeconds + 1));

  // --- Test Speaker Flow ---
  print('\n▶︎ Switching to speaker flow...');
  await engine.stop();

  await engine.startSession('en');
  print('🔊 Please speak something into the mic now (20s window)...');
  await Future.delayed(Duration(seconds: 20));
  await engine.stop();

  // Clean up
  await sub.cancel();
  print('✅ HermesEngine dev runner completed.');
}
