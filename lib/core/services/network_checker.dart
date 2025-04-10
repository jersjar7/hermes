// lib/core/services/network_checker.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

/// Service to check network connectivity status
@lazySingleton
class NetworkChecker {
  final Connectivity _connectivity;

  /// Creates a new [NetworkChecker]
  NetworkChecker(this._connectivity) {
    print("[NETWORK_DEBUG] NetworkChecker initialized");
  }

  /// Factory constructor with default Connectivity instance
  @factoryMethod
  static NetworkChecker create() {
    print("[NETWORK_DEBUG] Creating NetworkChecker");
    return NetworkChecker(Connectivity());
  }

  /// Check if there is an active internet connection
  ///
  /// FOR DEBUGGING: This is temporarily hardcoded to return true
  /// to isolate other issues during development
  Future<bool> hasConnection() async {
    // print(
    //   "[NETWORK_DEBUG] hasConnection called - returning true for debugging",
    // );

    // DEBUG: Return true for debugging purposes
    // return true;

    // Actual implementation (commented out for debugging)

    try {
      final result = await _connectivity.checkConnectivity();
      print("[NETWORK_DEBUG] Connectivity result: $result");
      return result != ConnectivityResult.none;
    } catch (e) {
      print("[NETWORK_DEBUG] Error checking connectivity: $e");
      return false;
    }
  }

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    print("[NETWORK_DEBUG] onConnectivityChanged accessed");
    return _connectivity.onConnectivityChanged;
  }

  /// Check if connection is wifi
  Future<bool> isConnectedViaWifi() async {
    try {
      final result = await _connectivity.checkConnectivity();
      print("[NETWORK_DEBUG] isConnectedViaWifi: $result");
      return result == ConnectivityResult.wifi;
    } catch (e) {
      print("[NETWORK_DEBUG] Error checking wifi: $e");
      return false;
    }
  }

  /// Check if connection is mobile data
  Future<bool> isConnectedViaMobile() async {
    try {
      final result = await _connectivity.checkConnectivity();
      print("[NETWORK_DEBUG] isConnectedViaMobile: $result");
      return result == ConnectivityResult.mobile;
    } catch (e) {
      print("[NETWORK_DEBUG] Error checking mobile: $e");
      return false;
    }
  }
}
