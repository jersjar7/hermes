// lib/core/services/permission/permission_service_impl.dart
import 'package:permission_handler/permission_handler.dart';
import 'permission_service.dart';

class PermissionServiceImpl implements IPermissionService {
  @override
  Future<bool> requestMicrophonePermission() async =>
      (await Permission.microphone.request()).isGranted;

  @override
  Future<bool> hasMicrophonePermission() async =>
      await Permission.microphone.isGranted;
}
