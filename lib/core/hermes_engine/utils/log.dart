// lib/core/hermes_engine/utils/log.dart

import 'package:hermes/core/services/logger/logger_service.dart';

/// Helper to standardize and simplify logging in HermesEngine.
class HermesLogger {
  final ILoggerService _logger;
  final String _context;

  /// [context] defaults to 'HermesEngine' if not provided.
  HermesLogger(this._logger, [this._context = 'HermesEngine']);

  /// Logs an informational message with optional [tag].
  void info(String message, {String? tag}) {
    final prefixed = _prefix(message, tag);
    _logger.logInfo(prefixed, context: _context);
  }

  /// Logs an error message, along with optional [error], [stackTrace], and [tag].
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    final prefixed = _prefix(message, tag);
    _logger.logError(
      prefixed,
      error: error,
      stackTrace: stackTrace,
      context: _context,
    );
  }

  String _prefix(String msg, String? tag) {
    return tag != null ? '[$tag] $msg' : msg;
  }
}
