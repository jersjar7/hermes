import 'package:flutter/foundation.dart';
import 'package:hermes/core/services/device_info/device_info_service.dart';
import 'logger_service.dart';

class LoggerServiceImpl implements ILoggerService {
  final IDeviceInfoService _deviceInfo;

  LoggerServiceImpl(this._deviceInfo);

  @override
  void logInfo(String message, {String? context}) {
    final tag = context != null ? '[$context]' : '[INFO]';
    final device =
        _deviceInfoInitialized
            ? '[${_deviceInfo.platform} ${_deviceInfo.model}]'
            : '[DeviceInfo not initialized]';
    debugPrint('$tag $message $device');
  }

  @override
  void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? context,
  }) {
    final tag = context != null ? '[$context]' : '[ERROR]';
    final device =
        _deviceInfoInitialized
            ? '[${_deviceInfo.platform} ${_deviceInfo.model}]'
            : '[DeviceInfo not initialized]';
    debugPrint('$tag $message $device');
    if (error != null) debugPrint('   ↳ Error: $error');
    if (stackTrace != null) debugPrint('   ↳ StackTrace: $stackTrace');
  }

  bool get _deviceInfoInitialized {
    try {
      // Accessing a late final field will throw if uninitialized
      _deviceInfo.platform;
      return true;
    } catch (_) {
      return false;
    }
  }
}
