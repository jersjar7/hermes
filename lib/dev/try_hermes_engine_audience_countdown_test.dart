// lib/dev/try_hermes_engine_audience_countdown_test.dart

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/hermes_engine/audience/audience_engine.dart';
import 'package:hermes/core/hermes_engine/config/hermes_config.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
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

  print('▶︎ Starting audience countdown & playback test...');

  final sub = engine.stream.listen((state) {
    print('🔄 Audience state: $state');
    if (state.status == HermesStatus.countdown) {
      print('⏳ Countdown started: ${state.countdownSeconds} seconds remaining');
    }
    if (state.status == HermesStatus.speaking) {
      print('✅ Engine entered SPEAKING state as expected!');
    }
  });

  const code = 'DEV01';
  await engine.start(sessionCode: code);

  // Emit three translation events to exceed buffer threshold
  for (int i = 1; i <= 3; i++) {
    final text = 'Segment #$i';
    print('📡 Emitting TranslationEvent: "$text"');
    socket.send(
      TranslationEvent(
        sessionId: code,
        translatedText: text,
        targetLanguage: 'en',
      ),
    );
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // Wait long enough for countdown + some playback
  final waitSeconds = kInitialBufferCountdownSeconds + 2;
  print('⌛ Waiting $waitSeconds seconds for countdown and playback...');
  await Future.delayed(Duration(seconds: waitSeconds));

  // Clean up
  engine.dispose();
  await sub.cancel();

  print('✅ Audience countdown & playback test completed.');
}
