// ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register the modular continuous speech plugin (iOS 10.0+)
    if #available(iOS 10.0, *) {
        ContinuousSpeechPlugin.register(with: registrar(forPlugin: "ContinuousSpeechPlugin")!)
        print("✅ [AppDelegate] Modular ContinuousSpeechPlugin registered")
    } else {
        print("❌ [AppDelegate] iOS 10.0+ required for speech recognition")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
