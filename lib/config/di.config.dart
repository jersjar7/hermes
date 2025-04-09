// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../core/services/audio_player_service.dart' as _i835;
import '../core/services/network_checker.dart' as _i137;
import '../core/utils/logger.dart' as _i503;
import '../features/session/domain/repositories/session_repository.dart'
    as _i65;
import '../features/session/domain/usecases/create_session.dart' as _i1033;
import '../features/session/domain/usecases/end_session.dart' as _i217;
import '../features/session/domain/usecases/get_active_sessions.dart' as _i674;
import '../features/session/domain/usecases/join_session.dart' as _i649;
import '../features/session/infrastructure/datasources/session_remote_ds.dart'
    as _i368;
import '../features/session/infrastructure/repositories/session_repo_impl.dart'
    as _i331;
import '../features/session/infrastructure/services/auth_service.dart' as _i374;
import '../features/translation/domain/repositories/transcription_repository.dart'
    as _i187;
import '../features/translation/domain/repositories/translation_repository.dart'
    as _i775;
import '../features/translation/domain/usecases/stream_transcription.dart'
    as _i443;
import '../features/translation/domain/usecases/translate_text_chunk.dart'
    as _i1006;
import '../features/translation/infrastructure/repositories/transcription_repo_impl.dart'
    as _i1048;
import '../features/translation/infrastructure/repositories/translation_repo_impl.dart'
    as _i77;
import '../features/translation/infrastructure/services/speech_to_text_service.dart'
    as _i304;
import '../features/translation/infrastructure/services/translation_service.dart'
    as _i1060;
import '../features/translation/presentation/controllers/audience_controller.dart'
    as _i202;
import '../features/translation/presentation/controllers/speaker_controller.dart'
    as _i724;
import 'firebase_config.dart' as _i352;
import 'session_module.dart' as _i849;
import 'translation_module.dart' as _i458;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final firebaseInjectableModule = _$FirebaseInjectableModule();
  final translationInjectableModule = _$TranslationInjectableModule();
  final sessionInjectableModule = _$SessionInjectableModule();
  gh.lazySingleton<_i503.Logger>(() => _i503.Logger.create());
  gh.lazySingleton<_i137.NetworkChecker>(() => _i137.NetworkChecker.create());
  gh.lazySingleton<_i835.AudioPlayerService>(
    () => _i835.AudioPlayerService.create(),
  );
  gh.lazySingleton<_i59.FirebaseAuth>(
    () => firebaseInjectableModule.firebaseAuth,
  );
  gh.lazySingleton<_i974.FirebaseFirestore>(
    () => firebaseInjectableModule.firestore,
  );
  gh.lazySingleton<_i457.FirebaseStorage>(
    () => firebaseInjectableModule.firebaseStorage,
  );
  gh.lazySingleton<_i304.SpeechToTextService>(
    () => translationInjectableModule.provideSpeechToTextService(
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i1060.TranslationService>(
    () => translationInjectableModule.provideTranslationService(
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i187.TranscriptionRepository>(
    () => _i1048.TranscriptionRepositoryImpl(
      gh<_i304.SpeechToTextService>(),
      gh<_i974.FirebaseFirestore>(),
      gh<_i137.NetworkChecker>(),
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i443.StreamTranscription>(
    () => translationInjectableModule.provideStreamTranscription(
      gh<_i187.TranscriptionRepository>(),
    ),
  );
  gh.lazySingleton<_i775.TranslationRepository>(
    () => _i77.TranslationRepositoryImpl(
      gh<_i1060.TranslationService>(),
      gh<_i974.FirebaseFirestore>(),
      gh<_i137.NetworkChecker>(),
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i368.SessionRemoteDataSource>(
    () => _i368.SessionRemoteDataSource(
      gh<_i974.FirebaseFirestore>(),
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i374.AuthService>(
    () => sessionInjectableModule.authService(
      gh<_i59.FirebaseAuth>(),
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i1006.TranslateTextChunk>(
    () => translationInjectableModule.provideTranslateTextChunk(
      gh<_i775.TranslationRepository>(),
    ),
  );
  gh.factory<_i202.AudienceController>(
    () => _i202.AudienceController(
      gh<_i187.TranscriptionRepository>(),
      gh<_i775.TranslationRepository>(),
      gh<_i503.Logger>(),
    ),
  );
  gh.factory<_i724.SpeakerController>(
    () => _i724.SpeakerController(
      gh<_i443.StreamTranscription>(),
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i65.SessionRepository>(
    () => _i331.SessionRepositoryImpl(
      gh<_i368.SessionRemoteDataSource>(),
      gh<_i137.NetworkChecker>(),
      gh<_i503.Logger>(),
    ),
  );
  gh.lazySingleton<_i1033.CreateSession>(
    () => sessionInjectableModule.createSession(gh<_i65.SessionRepository>()),
  );
  gh.lazySingleton<_i649.JoinSession>(
    () => sessionInjectableModule.joinSession(gh<_i65.SessionRepository>()),
  );
  gh.lazySingleton<_i217.EndSession>(
    () => sessionInjectableModule.endSession(gh<_i65.SessionRepository>()),
  );
  gh.lazySingleton<_i674.GetActiveSessions>(
    () =>
        sessionInjectableModule.getActiveSessions(gh<_i65.SessionRepository>()),
  );
  return getIt;
}

class _$FirebaseInjectableModule extends _i352.FirebaseInjectableModule {}

class _$TranslationInjectableModule extends _i458.TranslationInjectableModule {}

class _$SessionInjectableModule extends _i849.SessionInjectableModule {}
