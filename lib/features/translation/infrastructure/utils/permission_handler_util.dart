// lib/features/translation/infrastructure/utils/permission_handler_util.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hermes/core/utils/logger.dart';

/// Utility class for handling permissions consistently across the app
class PermissionHandlerUtil {
  final Logger _logger;

  /// Creates a new [PermissionHandlerUtil]
  PermissionHandlerUtil(this._logger);

  /// Check if microphone permission is granted
  /// Returns a tuple with (hasPermission, permissionStatus)
  Future<(bool, PermissionStatus)> checkMicrophonePermission() async {
    _logger.d("[PERMISSION_DEBUG] Checking microphone permission");

    try {
      final status = await Permission.microphone.status;
      _logger.d(
        "[PERMISSION_DEBUG] Current microphone permission status: $status",
      );

      if (status.isGranted) {
        return (true, status);
      }

      // If permission is denied but can be requested
      if (status.isDenied) {
        _logger.d("[PERMISSION_DEBUG] Permission is denied, requesting...");
        final requestResult = await Permission.microphone.request();
        _logger.d(
          "[PERMISSION_DEBUG] Permission request result: $requestResult",
        );

        return (requestResult.isGranted, requestResult);
      }

      // If permission is permanently denied or restricted
      return (false, status);
    } catch (e) {
      _logger.e("[PERMISSION_DEBUG] Error checking permission", error: e);
      // Return denied status as fallback
      return (false, PermissionStatus.denied);
    }
  }

  /// Show permission settings dialog
  void showPermissionSettingsDialog(
    BuildContext context, {
    String title = 'Microphone Permission Required',
    String message =
        'Hermes needs microphone access to transcribe your speech. Please enable microphone permission in settings.',
    VoidCallback? onCancel,
  }) {
    _logger.d("[PERMISSION_DEBUG] Showing permission settings dialog");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onCancel != null) onCancel();
                },
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  /// Helper method to determine if we should show settings dialog
  bool shouldShowSettingsDialog(PermissionStatus status) {
    return status.isPermanentlyDenied || status.isRestricted;
  }

  /// Get a user-friendly error message based on permission status
  String getPermissionErrorMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.denied:
        return 'Microphone permission is required to transcribe speech. Please grant access when prompted.';
      case PermissionStatus.permanentlyDenied:
        return 'Microphone permission is permanently denied. Please enable it in app settings.';
      case PermissionStatus.restricted:
        return 'Microphone access is restricted on this device.';
      case PermissionStatus.limited:
        return 'Microphone has limited permissions. Full access is needed.';
      default:
        return 'Microphone permission is required for speech recognition.';
    }
  }
}
