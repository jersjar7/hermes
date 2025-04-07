// lib/core/services/network_checker.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

/// Service to check network connectivity status
@lazySingleton
class NetworkChecker {
  final Connectivity _connectivity;

  /// Creates a new [NetworkChecker]
  NetworkChecker(this._connectivity);

  /// Factory constructor with default Connectivity instance
  @factoryMethod
  static NetworkChecker create() => NetworkChecker(Connectivity());

  /// Check if there is an active internet connection
  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Check if connection is wifi
  Future<bool> isConnectedViaWifi() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.wifi;
  }

  /// Check if connection is mobile data
  Future<bool> isConnectedViaMobile() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.mobile;
  }
}
