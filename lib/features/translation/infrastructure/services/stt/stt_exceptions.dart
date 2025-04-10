// lib/features/translation/infrastructure/services/stt/stt_exceptions.dart

import 'package:permission_handler/permission_handler.dart';

/// Base class for all STT service exceptions
abstract class SttException implements Exception {
  final String message;

  SttException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when microphone permission is not granted
class MicrophonePermissionException extends SttException {
  final PermissionStatus permissionStatus;

  MicrophonePermissionException(
    super.message, {
    required this.permissionStatus,
  });
}

/// Exception thrown when Google Cloud STT API returns an error
class SttApiException extends SttException {
  final int? statusCode;
  final String? responseBody;

  SttApiException(super.message, {this.statusCode, this.responseBody});

  @override
  String toString() {
    if (statusCode != null) {
      return 'STT API Error (status $statusCode): $message';
    }
    return 'STT API Error: $message';
  }
}

/// Exception thrown when audio recording/processing fails
class AudioProcessingException extends SttException {
  AudioProcessingException(super.message);
}

/// Exception thrown when STT service initialization fails
class SttServiceInitializationException extends SttException {
  SttServiceInitializationException(super.message);
}
