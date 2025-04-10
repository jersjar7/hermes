// lib/features/translation/infrastructure/di/stt_module.dart

import 'package:injectable/injectable.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_service.dart';

/// Module for providing Speech-to-Text related dependencies
@module
abstract class SttInjectableModule {
  /// Provide Speech-to-Text service
  @lazySingleton
  SpeechToTextService provideSpeechToTextService(Logger logger) =>
      SpeechToTextService.create(logger);
}
