// lib/features/session/presentation/providers/connection_state_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';

/// Represents the overall connection state of the app.
class HermesConnectionState {
  final bool isNetworkOnline;
  final bool isSocketConnected;
  final String connectionType;
  final String? error;

  const HermesConnectionState({
    required this.isNetworkOnline,
    required this.isSocketConnected,
    required this.connectionType,
    this.error,
  });

  /// Overall connection health - both network and socket must be good
  bool get isFullyConnected => isNetworkOnline && isSocketConnected;

  /// Is connecting if network is online but socket isn't connected yet
  bool get isConnecting => isNetworkOnline && !isSocketConnected;

  /// Connection status message for UI display
  String get statusMessage {
    if (error != null) return 'Connection Error';
    if (!isNetworkOnline) return 'No Internet';
    if (isConnecting) return 'Connecting...';
    if (isFullyConnected) return 'Connected';
    return 'Disconnected';
  }

  HermesConnectionState copyWith({
    bool? isNetworkOnline,
    bool? isSocketConnected,
    String? connectionType,
    String? error,
  }) {
    return HermesConnectionState(
      isNetworkOnline: isNetworkOnline ?? this.isNetworkOnline,
      isSocketConnected: isSocketConnected ?? this.isSocketConnected,
      connectionType: connectionType ?? this.connectionType,
      error: error ?? this.error,
    );
  }
}

/// Provider that monitors both network connectivity and socket connection.
final connectionStateProvider = StreamProvider<HermesConnectionState>((ref) {
  final connectivityService = getIt<IConnectivityService>();
  final socketService = getIt<ISocketService>();

  // Initialize connectivity service
  connectivityService.initialize();

  late StreamController<HermesConnectionState> controller;
  late StreamSubscription connectivitySub;
  Timer? socketCheckTimer;

  HermesConnectionState currentState = HermesConnectionState(
    isNetworkOnline: connectivityService.isOnline,
    isSocketConnected: socketService.isConnected,
    connectionType: 'unknown',
  );

  void updateState() {
    final newState = HermesConnectionState(
      isNetworkOnline: connectivityService.isOnline,
      isSocketConnected: socketService.isConnected,
      connectionType: currentState.connectionType,
    );

    if (newState.isNetworkOnline != currentState.isNetworkOnline ||
        newState.isSocketConnected != currentState.isSocketConnected) {
      currentState = newState;
      controller.add(currentState);
    }
  }

  void getConnectionType() async {
    try {
      final type = await connectivityService.getConnectionType();
      currentState = currentState.copyWith(connectionType: type);
      controller.add(currentState);
    } catch (e) {
      currentState = currentState.copyWith(error: e.toString());
      controller.add(currentState);
    }
  }

  controller = StreamController<HermesConnectionState>(
    onListen: () {
      // Initial state
      getConnectionType();
      controller.add(currentState);

      // Listen to connectivity changes
      connectivitySub = connectivityService.onStatusChange.listen((_) {
        updateState();
        getConnectionType();
      });

      // Poll socket status every 2 seconds
      socketCheckTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => updateState(),
      );
    },
    onCancel: () {
      connectivitySub.cancel();
      socketCheckTimer?.cancel();
    },
  );

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});

/// Simple provider for quick connection checks in widgets
final isConnectedProvider = Provider<bool>((ref) {
  final connectionAsync = ref.watch(connectionStateProvider);
  return connectionAsync.when(
    data: (state) => state.isFullyConnected,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider for connection status suitable for UI display
final connectionStatusProvider =
    Provider<({bool connected, bool connecting, String message})>((ref) {
      final connectionAsync = ref.watch(connectionStateProvider);

      return connectionAsync.when(
        data:
            (state) => (
              connected: state.isFullyConnected,
              connecting: state.isConnecting,
              message: state.statusMessage,
            ),
        loading:
            () => (
              connected: false,
              connecting: true,
              message: 'Initializing...',
            ),
        error:
            (error, _) => (
              connected: false,
              connecting: false,
              message: 'Connection Error',
            ),
      );
    });
