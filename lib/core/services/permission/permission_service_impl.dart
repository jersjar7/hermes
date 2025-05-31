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

    // If permanently denied, guide user to settings
    if (currentStatus.isPermanentlyDenied) {
      print(
        '🚫 [PermissionService] Permission permanently denied - opening settings',
      );
      await openAppSettings();
      return false;
    }

    // Request permission
    print('🔄 [PermissionService] Requesting microphone permission...');
    final result = await Permission.microphone.request();
    print('📋 [PermissionService] Permission request result: $result');

    // Handle different results
    switch (result) {
      case PermissionStatus.granted:
        print('✅ [PermissionService] Permission granted successfully');
        return true;
      case PermissionStatus.denied:
        print('❌ [PermissionService] Permission denied by user');
        return false;
      case PermissionStatus.permanentlyDenied:
        print('🚫 [PermissionService] Permission permanently denied');
        await openAppSettings();
        return false;
      default:
        print('⚠️ [PermissionService] Unexpected permission status: $result');
        return false;
    }
  }

  @override
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    print('📱 [PermissionService] Current permission check: $status');
    return status.isGranted;
  }
}
