import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();

  final connectivity = getIt<IConnectivityService>();
  await connectivity.initialize();

  final initialType = await connectivity.getConnectionType();
  print('🌐 Initial connection: $initialType');

  connectivity.onStatusChange.listen((isOnline) {
    print(isOnline ? '✅ Online' : '❌ Offline');
  });
}
