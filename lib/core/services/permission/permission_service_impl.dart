// lib/core/services/permission/permission_service_impl.dart

import 'package:permission_handler/permission_handler.dart';
import 'permission_service.dart';

class PermissionServiceImpl implements IPermissionService {
  @override
  Future<bool> requestMicrophonePermission() async {
    print(
      '🎤 [PermissionService] Checking current microphone permission status...',
    );

    // First check current status
    final currentStatus = await Permission.microphone.status;
    print('📱 [PermissionService] Current permission status: $currentStatus');

    // If already granted, return true
    if (currentStatus.isGranted) {
      print('✅ [PermissionService] Permission already granted');
      return true;
    }

    // If permanently denied, we need special handling
    if (currentStatus.isPermanentlyDenied) {
      print('🚫 [PermissionService] Permission permanently denied');
      // Don't open settings automatically - let the UI handle this
      return false;
    }

    // If denied but not permanently, we can request again
    if (currentStatus.isDenied) {
      print('🔄 [PermissionService] Permission denied, requesting again...');
      final result = await Permission.microphone.request();
      print('📋 [PermissionService] Permission request result: $result');
      return result.isGranted;
    }

    // For any other status (like restricted), request permission
    print('🔄 [PermissionService] Requesting microphone permission...');
    final result = await Permission.microphone.request();
    print('📋 [PermissionService] Permission request result: $result');

    return result.isGranted;
  }

  @override
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    print('📱 [PermissionService] Current permission check: $status');
    return status.isGranted;
  }

  /// Check if permission is permanently denied
  Future<bool> isMicrophonePermissionPermanentlyDenied() async {
    final status = await Permission.microphone.status;
    return status.isPermanentlyDenied;
  }

  /// Open app settings for user to manually enable permissions
  Future<void> openSettings() async {
    print('🔧 [PermissionService] Opening app settings...');
    await openAppSettings();
  }
}
