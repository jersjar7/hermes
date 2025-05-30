// lib/dev/try_hermes_engine_speaker.dart

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/hermes_engine/speaker/speaker_engine.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupServiceLocator();

  final permission = getIt<IPermissionService>();
  final stt = getIt<ISpeechToTextService>();
  final translator = getIt<ITranslationService>();
  final tts = getIt<ITextToSpeechService>();
  final session = getIt<ISessionService>();
  final socket = getIt<ISocketService>();
  final connectivity = getIt<IConnectivityService>();
  final logger = getIt<ILoggerService>();

  final engine = SpeakerEngine(
    permission: permission,
    stt: stt,
    translator: translator,
    tts: tts,
    session: session,
    socket: socket,
    connectivity: connectivity,
    logger: logger,
  );

  print('▶︎ Starting speaker flow...');
  final sub = engine.stream.listen((state) {
    print('🔄 Speaker state: $state');
  });

  // Start speaker session in English
  await engine.start(languageCode: 'en');
  print('🎤 Engine started, you may speak now (15s)...');

  // Listen for 15 seconds
  await Future.delayed(Duration(seconds: 15));

  engine.dispose();
  await sub.cancel();

  print('✅ Speaker engine test completed.');
}
