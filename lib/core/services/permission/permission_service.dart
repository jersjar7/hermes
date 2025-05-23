abstract class IPermissionService {
  Future<bool> requestMicrophonePermission();
  Future<bool> hasMicrophonePermission();
}
