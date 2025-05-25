// lib/dev/try_hermes_engine_audience.dart

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/hermes_engine/audience/audience_engine.dart';
import 'package:hermes/core/hermes_engine/config/hermes_config.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupServiceLocator();

  final session = getIt<ISessionService>();
  final socket = getIt<ISocketService>();
  final connectivity = getIt<IConnectivityService>();
  final logger = getIt<ILoggerService>();

  final engine = AudienceEngine(
    session: session,
    socket: socket,
    connectivity: connectivity,
    logger: logger,
  );

  print('▶︎ Starting audience flow...');

  final sub = engine.stream.listen((state) {
    print('🔄 Audience state: $state');
  });

  const code = 'DEV01';
  await engine.start(sessionCode: code);
  print('✅ Joined session $code');

  // Simulate incoming translations
  socket.send(
    TranslationEvent(
      sessionId: code,
      translatedText: 'Hello from speaker!',
      targetLanguage: 'en',
    ),
  );
  print('📡 Sent test TranslationEvent');

  // Wait for buffer -> countdown
  await Future.delayed(Duration(seconds: kInitialBufferCountdownSeconds + 2));

  // Clean up
  engine.dispose();
  await sub.cancel();

  print('✅ Audience engine test completed.');
}
