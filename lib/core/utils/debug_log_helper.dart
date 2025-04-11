// lib/core/utils/debug_log_helper.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Helper class for managing debug logs and diagnostic information
class DebugLogHelper {
  final Logger _logger;
  final StringBuffer _logBuffer = StringBuffer();
  bool _isCollectingLogs = false;
  final int _maxLogSize = 1000000; // ~1MB max log size

  /// Creates a new [DebugLogHelper]
  DebugLogHelper(this._logger);

  /// Start collecting logs
  void startLogging() {
    _isCollectingLogs = true;
    _logBuffer.clear();
    _logBuffer.writeln("=== DEBUG LOG START: ${DateTime.now()} ===");
    _logger.d("[DEBUG_LOG] Started collecting logs");
  }

  /// Stop collecting logs
  void stopLogging() {
    _isCollectingLogs = false;
    _logBuffer.writeln("=== DEBUG LOG END: ${DateTime.now()} ===");
    _logger.d("[DEBUG_LOG] Stopped collecting logs");
  }

  /// Add a log entry
  void log(String message) {
    if (_isCollectingLogs) {
      final timestamp = DateTime.now().toString();
      final entry = "[$timestamp] $message";

      // Only keep last ~1MB of logs to avoid memory issues
      if (_logBuffer.length > _maxLogSize) {
        final currentContent = _logBuffer.toString();
        final truncatedContent = currentContent.substring(
          currentContent.length ~/ 2,
          currentContent.length,
        );
        _logBuffer.clear();
        _logBuffer.writeln("... TRUNCATED ...");
        _logBuffer.write(truncatedContent);
      }

      _logBuffer.writeln(entry);
    }
  }

  /// Get all collected logs
  String getLogs() {
    return _logBuffer.toString();
  }

  /// Save logs to a file
  Future<String?> saveLogsToFile() async {
    try {
      if (_logBuffer.isEmpty) {
        _logger.d("[DEBUG_LOG] No logs to save");
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/debug_log_$timestamp.txt';

      final file = File(filePath);
      await file.writeAsString(_logBuffer.toString());

      _logger.d("[DEBUG_LOG] Logs saved to: $filePath");
      return filePath;
    } catch (e) {
      _logger.e("[DEBUG_LOG] Failed to save logs", error: e);
      return null;
    }
  }

  /// Collect system info
  Map<String, dynamic> collectSystemInfo() {
    return {
      'platform': defaultTargetPlatform.toString(),
      'timestamp': DateTime.now().toString(),
      'isDebugMode': kDebugMode,
      'isReleaseMode': kReleaseMode,
      'isProfileMode': kProfileMode,
    };
  }

  /// Get detailed audio diagnostics
  Map<String, dynamic> getAudioDiagnostics({
    required bool micPermissionGranted,
    required bool isRecording,
    required bool isStreaming,
    required bool hasError,
    required String? errorMessage,
    required int elapsedTimeMs,
  }) {
    return {
      'micPermissionGranted': micPermissionGranted,
      'isRecording': isRecording,
      'isStreaming': isStreaming,
      'hasError': hasError,
      'errorMessage': errorMessage,
      'elapsedTimeMs': elapsedTimeMs,
      'timestamp': DateTime.now().toString(),
    };
  }
}
