// lib/core/service_locator.dart

import 'package:get_it/get_it.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Core services
import 'package:hermes/core/services/auth/auth_service.dart';
import 'package:hermes/core/services/auth/auth_service_impl.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service_impl.dart';
import 'package:hermes/core/services/device_info/device_info_service.dart';
import 'package:hermes/core/services/device_info/device_info_service_impl.dart';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/logger/logger_service_impl.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/permission/permission_service_impl.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service_impl.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/translation/translation_service_impl.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service_impl.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_service_impl.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/session/session_service_impl.dart';

// HermesEngine components
import 'package:hermes/core/hermes_engine/speaker/speaker_engine.dart';
import 'package:hermes/core/hermes_engine/audience/audience_engine.dart';
import 'package:hermes/core/hermes_engine/buffer/translation_buffer.dart';
import 'package:hermes/core/hermes_engine/buffer/countdown_timer.dart';
import 'package:hermes/core/hermes_engine/usecases/playback_control.dart';
import 'package:hermes/core/hermes_engine/utils/log.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // 📱 Device Info
  getIt.registerLazySingleton<IDeviceInfoService>(
    () => DeviceInfoServiceImpl(),
  );
  await getIt<IDeviceInfoService>().initialize();

  // 📋 Logger (uses DeviceInfo under the hood)
  getIt.registerLazySingleton<ILoggerService>(
    () => LoggerServiceImpl(getIt<IDeviceInfoService>()),
  );

  // 🎤 Permissions
  getIt.registerLazySingleton<IPermissionService>(
    () => PermissionServiceImpl(),
  );

  // 🔉 Speech-to-Text (needs logger)
  getIt.registerLazySingleton<ISpeechToTextService>(
    () => SpeechToTextServiceImpl(getIt<ILoggerService>()),
  );

  // 🌐 Translation (API key from .env)
  getIt.registerLazySingleton<ITranslationService>(
    () => TranslationServiceImpl(apiKey: dotenv.env['TRANSLATION_API_KEY']!),
  );

  // 🔊 Text-to-Speech (needs logger)
  getIt.registerLazySingleton<ITextToSpeechService>(
    () => TextToSpeechServiceImpl(getIt<ILoggerService>()),
  );

  // 📡 Socket (needs logger)
  getIt.registerLazySingleton<ISocketService>(
    () => SocketServiceImpl(getIt<ILoggerService>()),
  );

  // 🌐 Connectivity
  getIt.registerLazySingleton<IConnectivityService>(
    () => ConnectivityServiceImpl(),
  );
  await getIt<IConnectivityService>().initialize();

  // 👤 Authentication
  getIt.registerLazySingleton<IAuthService>(() => AuthServiceImpl());

  // 🎛️ Session management - 🎯 SIMPLIFIED: Only needs logger now
  getIt.registerLazySingleton<ISessionService>(
    () => SessionServiceImpl(
      logger: getIt<ILoggerService>(),
      // 🎯 NO MORE SOCKET DEPENDENCY: Socket connection moved to speaker engine
    ),
  );

  // ─────────────────────────────────────────────
  // 🎯 CRITICAL CHANGE: HermesEngine Components - NOW USING FACTORIES FOR FRESH INSTANCES

  // 🎯 CHANGED: Create fresh buffer for each session
  getIt.registerFactory<TranslationBuffer>(() => TranslationBuffer());

  // HermesLogger can stay singleton (safe to reuse)
  getIt.registerLazySingleton<HermesLogger>(
    () => HermesLogger(getIt<ILoggerService>()),
  );

  // 🎯 CHANGED: Create fresh countdown timer for each session
  getIt.registerFactory<CountdownTimer>(() => CountdownTimer());

  // 🎯 CHANGED: Create fresh playback control for each session
  getIt.registerFactory<PlaybackControlUseCase>(
    () => PlaybackControlUseCase(
      ttsService: getIt<ITextToSpeechService>(),
      buffer: getIt<TranslationBuffer>(), // This will get a fresh buffer
      logger: getIt<HermesLogger>(),
    ),
  );

  // 🎯 CHANGED: Create fresh speaker engine for each session
  getIt.registerFactory<SpeakerEngine>(
    () => SpeakerEngine(
      permission: getIt<IPermissionService>(),
      stt: getIt<ISpeechToTextService>(),
      translator: getIt<ITranslationService>(),
      tts: getIt<ITextToSpeechService>(),
      session: getIt<ISessionService>(),
      socket: getIt<ISocketService>(),
      connectivity: getIt<IConnectivityService>(),
      logger: getIt<ILoggerService>(),
    ),
  );

  // 🎯 CHANGED: Create fresh audience engine for each session
  getIt.registerFactory<AudienceEngine>(
    () => AudienceEngine(
      buffer: getIt<TranslationBuffer>(), // This will get a fresh buffer
      session: getIt<ISessionService>(),
      socket: getIt<ISocketService>(),
      connectivity: getIt<IConnectivityService>(),
      logger: getIt<ILoggerService>(),
    ),
  );
}
