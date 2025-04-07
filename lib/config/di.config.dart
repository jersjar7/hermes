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
import 'firebase_config.dart' as _i352;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final firebaseInjectableModule = _$FirebaseInjectableModule();
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
  return getIt;
}

class _$FirebaseInjectableModule extends _i352.FirebaseInjectableModule {}
