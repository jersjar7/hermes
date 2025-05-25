// lib/core/hermes_engine/usecases/connectivity_handler.dart

import 'dart:async';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import '../utils/log.dart';

/// Use case to monitor connectivity status and trigger pause/resume actions.
class ConnectivityHandlerUseCase {
  final IConnectivityService connectivityService;
  final HermesLogger logger;

  StreamSubscription<bool>? _subscription;

  ConnectivityHandlerUseCase({
    required this.connectivityService,
    required this.logger,
  });

  /// Starts monitoring connectivity changes.
  /// Calls [onOffline] when connectivity drops,
  /// and [onOnline] when connectivity is restored.
  void startMonitoring({
    required void Function() onOffline,
    required void Function() onOnline,
  }) {
    _subscription = connectivityService.onStatusChange.listen((isOnline) {
      if (!isOnline) {
        logger.info('Connectivity lost', tag: 'ConnectivityHandler');
        onOffline();
      } else {
        logger.info('Connectivity restored', tag: 'ConnectivityHandler');
        onOnline();
      }
    });
  }

  /// Stops monitoring connectivity.
  void dispose() {
    _subscription?.cancel();
  }
}
