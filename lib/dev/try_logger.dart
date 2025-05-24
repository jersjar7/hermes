import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/device_info/device_info_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final deviceInfo = getIt<IDeviceInfoService>();
  await deviceInfo.initialize();

  final logger = getIt<ILoggerService>();
  logger.logInfo("Logger initialized!", context: "try_logger");
  logger.logError(
    "Something went wrong!",
    error: Exception("Example error"),
    context: "try_logger",
  );
}
