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

  // 👤 Authentication
  getIt.registerLazySingleton<IAuthService>(() => AuthServiceImpl());

  // 🎛️ Session orchestration (only needs socket & logger now)
  getIt.registerLazySingleton<ISessionService>(
    () => SessionServiceImpl(
      socketService: getIt<ISocketService>(),
      logger: getIt<ILoggerService>(),
    ),
  );

  // ─────────────────────────────────────────────
  // HermesEngine Components (for hermesControllerProvider)

  // Shared buffer instance
  getIt.registerLazySingleton<TranslationBuffer>(() => TranslationBuffer());

  // HermesLogger instance
  getIt.registerLazySingleton<HermesLogger>(
    () => HermesLogger(getIt<ILoggerService>()),
  );

  // Countdown timer
  getIt.registerLazySingleton<CountdownTimer>(() => CountdownTimer());

  // Playback control use case
  getIt.registerLazySingleton<PlaybackControlUseCase>(
    () => PlaybackControlUseCase(
      ttsService: getIt<ITextToSpeechService>(),
      buffer: getIt<TranslationBuffer>(),
      logger: getIt<HermesLogger>(),
    ),
  );

  // Speaker engine
  getIt.registerLazySingleton<SpeakerEngine>(
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

  // Audience engine (uses shared buffer)
  getIt.registerLazySingleton<AudienceEngine>(
    () => AudienceEngine(
      buffer: getIt<TranslationBuffer>(),
      session: getIt<ISessionService>(),
      socket: getIt<ISocketService>(),
      connectivity: getIt<IConnectivityService>(),
      logger: getIt<ILoggerService>(),
    ),
  );
}
