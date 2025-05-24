import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'connectivity_service.dart';

class ConnectivityServiceImpl implements IConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onStatusChange => _statusController.stream;

  @override
  Future<void> initialize() async {
    final initial = await _connectivity.checkConnectivity();
    _updateStatus(initial); // ✅ initial is already a List<ConnectivityResult>

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _statusController.add(_isOnline);
    }
  }

  @override
  Future<String> getConnectionType() async {
    final results = await _connectivity.checkConnectivity();

    final type = results.firstWhere(
      (r) => r != ConnectivityResult.none,
      orElse: () => ConnectivityResult.none,
    );

    switch (type) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'mobile';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.bluetooth:
        return 'bluetooth';
      case ConnectivityResult.none:
        return 'none';
      default:
        return 'unknown';
    }
  }

  void dispose() {
    _subscription.cancel();
    _statusController.close();
  }
}
