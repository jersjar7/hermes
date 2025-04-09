// lib/config/di.dart

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'di.config.dart';
import 'package:hermes/config/translation_module.dart';

/// Global service locator
final getIt = GetIt.instance;

/// Initializes dependency injection container
@InjectableInit(
  initializerName: 'init', // default
  preferRelativeImports: true, // default
  asExtension: false, // default
)
Future<void> configureDependencies() async => init(getIt);

/// Registers a singleton instance in the DI container
void registerSingleton<T extends Object>(T instance) {
  getIt.registerSingleton<T>(instance);
}

/// Registers a lazy singleton factory in the DI container
void registerLazySingleton<T extends Object>(T Function() factoryFunc) {
  getIt.registerLazySingleton<T>(factoryFunc);
}

/// Registers a factory in the DI container
void registerFactory<T extends Object>(T Function() factoryFunc) {
  getIt.registerFactory<T>(factoryFunc);
}
