// lib/core/services/logger/logger_service.dart

abstract class ILoggerService {
  /// Logs a general informational message.
  void logInfo(String message, {String? context});

  /// Logs an error with optional exception and stack trace.
  void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? context,
  });
}
