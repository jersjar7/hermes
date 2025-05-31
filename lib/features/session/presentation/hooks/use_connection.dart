// lib/features/session/presentation/hooks/use_connection.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/features/session/providers/connection_state_provider.dart';

/// Simple hook-style function to get connection status in widgets.
/// Returns a record with connection info for easy destructuring.
({bool connected, bool connecting, String message, String type}) useConnection(
  WidgetRef ref,
) {
  final connectionAsync = ref.watch(connectionStateProvider);

  return connectionAsync.when(
    data:
        (state) => (
          connected: state.isFullyConnected,
          connecting: state.isConnecting,
          message: state.statusMessage,
          type: state.connectionType,
        ),
    loading:
        () => (
          connected: false,
          connecting: true,
          message: 'Initializing...',
          type: 'unknown',
        ),
    error:
        (_, __) => (
          connected: false,
          connecting: false,
          message: 'Connection Error',
          type: 'none',
        ),
  );
}

/// Hook for simple boolean connection check
bool useIsConnected(WidgetRef ref) {
  return ref.watch(isConnectedProvider);
}

/// Example usage in widgets:
/// 
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final connection = useConnection(ref);
///     final isConnected = useIsConnected(ref);
///     
///     return Text(connection.connected ? 'Online' : 'Offline');
///   }
/// }