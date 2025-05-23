import 'package:permission_handler/permission_handler.dart';
import 'permission_service.dart';

class PermissionServiceImpl implements IPermissionService {
  @override
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  @override
  Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }
}
