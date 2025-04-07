// lib/core/errors/failure.dart

import 'package:equatable/equatable.dart';

/// Base class for all failures in the application
abstract class Failure extends Equatable {
  /// Error message
  final String message;

  /// Error code
  final int code;

  /// Creates a new [Failure] instance
  const Failure({required this.message, this.code = 0});

  @override
  List<Object> get props => [message, code];
}

/// Server failure when API calls fail
class ServerFailure extends Failure {
  /// Creates a new [ServerFailure] instance
  const ServerFailure({required super.message, super.code = 500});
}

/// Network failure when connection issues occur
class NetworkFailure extends Failure {
  /// Creates a new [NetworkFailure] instance
  const NetworkFailure({
    super.message = 'Network connection failed',
    super.code,
  });
}

/// Cache failure when local storage issues occur
class CacheFailure extends Failure {
  /// Creates a new [CacheFailure] instance
  const CacheFailure({super.message = 'Cache operation failed', super.code});
}

/// Authentication failure
class AuthFailure extends Failure {
  /// Creates a new [AuthFailure] instance
  const AuthFailure({
    super.message = 'Authentication failed',
    super.code = 401,
  });
}

/// Timeout failure
class TimeoutFailure extends Failure {
  /// Creates a new [TimeoutFailure] instance
  const TimeoutFailure({
    super.message = 'Operation timed out',
    super.code = 408,
  });
}

/// Validation failure
class ValidationFailure extends Failure {
  /// Creates a new [ValidationFailure] instance
  const ValidationFailure({
    super.message = 'Validation failed',
    super.code = 422,
  });
}

/// Speech recognition failure
class SpeechRecognitionFailure extends Failure {
  /// Creates a new [SpeechRecognitionFailure] instance
  const SpeechRecognitionFailure({
    super.message = 'Speech recognition failed',
    super.code,
  });
}

/// Translation failure
class TranslationFailure extends Failure {
  /// Creates a new [TranslationFailure] instance
  const TranslationFailure({super.message = 'Translation failed', super.code});
}

/// Text-to-speech failure
class TextToSpeechFailure extends Failure {
  /// Creates a new [TextToSpeechFailure] instance
  const TextToSpeechFailure({
    super.message = 'Text-to-speech conversion failed',
    super.code,
  });
}
