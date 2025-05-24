abstract class IDeviceInfoService {
  /// Initializes the device info lookup.
  Future<void> initialize();

  /// Returns a human-readable platform name (e.g., "iOS" or "Android").
  String get platform;

  /// Returns the device model (e.g., "iPhone 14 Pro" or "Pixel 6").
  String get model;

  /// Returns the OS version (e.g., "16.2" or "13").
  String get osVersion;

  /// True if the app is running on iOS.
  bool get isIOS;

  /// True if the app is running on Android.
  bool get isAndroid;
}
