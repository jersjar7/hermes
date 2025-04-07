// lib/core/utils/logger.dart

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Log levels for different types of messages
enum LogLevel {
  /// Debug level for detailed information
  debug,

  /// Info level for general information
  info,

  /// Warning level for potential issues
  warning,

  /// Error level for runtime errors
  error,
}

/// Logger utility to handle application logging
@lazySingleton
class Logger {
  /// Whether to show debug logs
  final bool _showDebugLogs;

  /// Creates a new [Logger] instance
  Logger({bool showDebugLogs = kDebugMode}) : _showDebugLogs = showDebugLogs;

  /// Factory constructor for normal logging mode
  @factoryMethod
  static Logger create() => Logger();

  /// Log a debug message
  void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_showDebugLogs) {
      _log(
        LogLevel.debug,
        message,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log an info message
  void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(
      LogLevel.info,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message
  void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(
      LogLevel.warning,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Internal logging method
  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final logTag = tag ?? 'Hermes';
    final logLevel = level.toString().split('.').last.toUpperCase();
    final logMessage = '[$logTag][$logLevel] $message';

    if (kDebugMode) {
      developer.log(
        logMessage,
        name: logTag,
        error: error,
        stackTrace: stackTrace,
        level: level.index,
      );
    }

    // In production, we might want to send logs to a service like Firebase Crashlytics
    if (level == LogLevel.error && !kDebugMode) {
      // TODO: Implement production error logging
      // FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }
}
