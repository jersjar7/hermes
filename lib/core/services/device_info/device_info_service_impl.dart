import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'device_info_service.dart';

class DeviceInfoServiceImpl implements IDeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  late String _platform;
  late String _model;
  late String _osVersion;

  @override
  Future<void> initialize() async {
    if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      _platform = "iOS";
      _model = ios.utsname.machine;
      _osVersion = ios.systemVersion;
    } else if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      _platform = "Android";
      _model = android.model;
      _osVersion = android.version.release;
    } else {
      _platform = "Unknown";
      _model = "Unknown";
      _osVersion = "Unknown";
    }
  }

  @override
  String get platform => _platform;

  @override
  String get model => _model;

  @override
  String get osVersion => _osVersion;

  @override
  bool get isIOS => _platform == "iOS";

  @override
  bool get isAndroid => _platform == "Android";
}
