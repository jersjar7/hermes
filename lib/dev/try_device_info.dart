import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/device_info/device_info_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final deviceInfo = getIt<IDeviceInfoService>();
  await deviceInfo.initialize();

  print('📱 Platform: ${deviceInfo.platform}');
  print('📦 Model: ${deviceInfo.model}');
  print('🧠 OS Version: ${deviceInfo.osVersion}');
}
