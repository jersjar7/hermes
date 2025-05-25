// lib/dev/try_all_services.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart'; // ← for ensureInitialized
import 'dart:async';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/auth/auth_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/device_info/device_info_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

Future<void> main() async {
  // ← This is critical for plugin initialization
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  print('👷‍♂️ Setting up service locator...');
  await setupServiceLocator();

  // Auth Service
  final auth = getIt<IAuthService>();
  print('🔑 Testing AuthService...');
  final user = await auth.signInAnonymously();
  print('  ✔ Signed in: $user');
  await auth.signOut();
  print('  ✔ Signed out');

  // Connectivity Service
  final connectivity = getIt<IConnectivityService>();
  print('🌐 Testing ConnectivityService...');
  await connectivity.initialize();
  final connType = await connectivity.getConnectionType();
  print('  ✔ Connection type: $connType');

  // Device Info Service
  final deviceInfo = getIt<IDeviceInfoService>();
  print('📱 Testing DeviceInfoService...');
  print('  ✔ Platform: ${deviceInfo.platform}');
  print('  ✔ Model: ${deviceInfo.model}');
  print('  ✔ OS Version: ${deviceInfo.osVersion}');

  // Logger Service
  final logger = getIt<ILoggerService>();
  print('📝 Testing LoggerService...');
  logger.logInfo('Info log test', context: 'DevRunner');
  logger.logError('Error log test', context: 'DevRunner');

  // Permission Service
  final permission = getIt<IPermissionService>();
  print('🔒 Testing PermissionService...');
  final hasPerm = await permission.requestMicrophonePermission();
  print('  ✔ Microphone permission granted: $hasPerm');

  // Speech-to-Text Service
  final stt = getIt<ISpeechToTextService>();
  print('🎤 Testing SpeechToTextService...');
  final sttInit = await stt.initialize();
  print('  ✔ STT initialized: $sttInit');
  final locales = await stt.getSupportedLocales();
  print('  ✔ Supported locales count: ${locales.length}');

  // Translation Service
  final translator = getIt<ITranslationService>();
  print('🌍 Testing TranslationService...');
  try {
    final result = await translator.translate(
      text: 'Hello, world!',
      targetLanguageCode: 'es',
    );
    print('  ✔ Translation: ${result.translatedText}');
  } catch (e) {
    print('  ❌ Translation failed: $e');
  }

  // Text-to-Speech Service
  final tts = getIt<ITextToSpeechService>();
  print('🔊 Testing TextToSpeechService...');
  await tts.initialize();
  await tts.speak('Testing text to speech');
  await Future.delayed(Duration(seconds: 2));
  final speaking = await tts.isSpeaking();
  print('  ✔ TTS speaking: $speaking');
  await tts.stop();

  // Socket Service
  final socket = getIt<ISocketService>();
  print('📡 Testing SocketService...');
  await socket.connect('TEST123');
  socket.onEvent.listen((event) {
    print('  ✔ Received socket event: $event');
  });
  socket.send(
    TranslationEvent(
      sessionId: 'TEST123',
      translatedText: 'Test event',
      targetLanguage: 'en',
    ),
  );
  await Future.delayed(Duration(seconds: 1));
  await socket.disconnect();

  // Session Service
  final session = getIt<ISessionService>();
  print('🔐 Testing SessionService...');
  await session.startSession(languageCode: 'en');
  print('  ✔ Started session: ${session.currentSession}');
  await session.pauseSession();
  print('  ✔ Paused session');
  await session.resumeSession();
  print('  ✔ Resumed session');
  await session.leaveSession();
  print('  ✔ Left session');

  print('✅ All services tested.');
}
