import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/device_info/device_info_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  // Ensure device info is initialized before logging
  final deviceInfo = getIt<IDeviceInfoService>();
  await deviceInfo.initialize();

  final logger = getIt<ILoggerService>();
  final socket = getIt<ISocketService>();

  await socket.connect('TEST01');

  socket.onEvent.listen((event) {
    logger.logInfo(
      'Event received: ${event.runtimeType}',
      context: 'try_socket_logger',
    );
    if (event is TranslationEvent) {
      logger.logInfo(
        'Message: ${event.translatedText}',
        context: 'try_socket_logger',
      );
    }
  });

  await socket.send(
    TranslationEvent(
      sessionId: 'TEST01',
      translatedText: 'Hello, world!',
      targetLanguage: 'en',
    ),
  );

  await Future.delayed(Duration(seconds: 2));

  await socket.disconnect();
}
