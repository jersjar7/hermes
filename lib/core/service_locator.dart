import 'package:get_it/get_it.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/session/session_service_impl.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_service_impl.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service_impl.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/translation/translation_service_impl.dart';

import 'services/speech_to_text/speech_to_text_service.dart';
import 'services/speech_to_text/speech_to_text_service_impl.dart';
import 'services/permission/permission_service.dart';
import 'services/permission/permission_service_impl.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<ISpeechToTextService>(
    () => SpeechToTextServiceImpl(),
  );
  getIt.registerLazySingleton<IPermissionService>(
    () => PermissionServiceImpl(),
  );
  getIt.registerLazySingleton<ITranslationService>(
    () => TranslationServiceImpl(
      apiKey: 'AIzaSyCLILZYMgAPdqa_iw_8Yf8EjMdzBdGz11A',
    ),
  );
  getIt.registerLazySingleton<ITextToSpeechService>(
    () => TextToSpeechServiceImpl(),
  );
  getIt.registerLazySingleton<ISocketService>(() => SocketServiceImpl());
  getIt.registerLazySingleton<ISessionService>(
    () => SessionServiceImpl(
      socketService: getIt<ISocketService>(),
      sttService: getIt<ISpeechToTextService>(),
      translationService: getIt<ITranslationService>(),
      ttsService: getIt<ITextToSpeechService>(),
    ),
  );
}
