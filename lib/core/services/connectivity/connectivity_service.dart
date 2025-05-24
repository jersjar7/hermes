import 'dart:async';

abstract class IConnectivityService {
  /// Starts monitoring the device's connection status.
  Future<void> initialize();

  /// Returns true if currently online.
  bool get isOnline;

  /// Emits true (online) or false (offline) when status changes.
  Stream<bool> get onStatusChange;

  /// Returns a human-readable connection type (e.g., 'wifi', 'mobile', 'none').
  Future<String> getConnectionType();
}
