import 'package:hermes/core/services/logger/logger_service.dart';

/// Helper to standardize HermesEngine logs.
class HermesLogger {
  final ILoggerService _logger;
  final String _context;

  HermesLogger(this._logger, [this._context = 'HermesEngine']);

  void info(String message, {String? tag}) {
    _logger.logInfo(_format(message, tag: tag), context: _context);
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    _logger.logError(
      _format(message, tag: tag),
      error: error,
      stackTrace: stackTrace,
      context: _context,
    );
  }

  String _format(String msg, {String? tag}) {
    final prefix = tag != null ? '[$tag] ' : '';
    return '$prefix$msg';
  }
}
