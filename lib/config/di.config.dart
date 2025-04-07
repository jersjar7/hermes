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
import 'firebase_config.dart' as _i352;
import 'session_module.dart' as _i849;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final firebaseInjectableModule = _$FirebaseInjectableModule();
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

class _$SessionInjectableModule extends _i849.SessionInjectableModule {}
