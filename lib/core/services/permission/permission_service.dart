// lib/core/services/permission/permission_service.dart

abstract class IPermissionService {
  Future<bool> requestMicrophonePermission();
  Future<bool> hasMicrophonePermission();

  /// Check if microphone permission is permanently denied
  Future<bool> isMicrophonePermissionPermanentlyDenied();

  /// Open device settings to allow user to manually enable permissions
  Future<void> openSettings();
}
