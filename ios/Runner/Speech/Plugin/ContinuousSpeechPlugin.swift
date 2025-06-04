// ios/Runner/Speech/Plugin/ContinuousSpeechPlugin.swift

import Flutter
import Foundation

/// Main Flutter plugin class for continuous speech recognition
/// Coordinates between method handling and event sending components
@available(iOS 10.0, *)
public class ContinuousSpeechPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Properties
    
    private var methodHandler: SpeechMethodHandler?
    private var eventSender: SpeechEventSender?
    
    // MARK: - Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        print("🚀 [ContinuousSpeechPlugin] Registering with Flutter...")
        
        let instance = ContinuousSpeechPlugin()
        instance.setup(with: registrar.messenger())
        
        print("✅ [ContinuousSpeechPlugin] Modular plugin registered successfully")
    }
    
    // MARK: - Setup
    
    private func setup(with binaryMessenger: FlutterBinaryMessenger) {
        print("🔧 [ContinuousSpeechPlugin] Setting up plugin components...")
        
        // Create event sender first (method handler depends on it)
        eventSender = SpeechEventSender(binaryMessenger: binaryMessenger)
        
        // Create method handler with event sender
        guard let eventSender = eventSender else {
            print("❌ [ContinuousSpeechPlugin] Failed to create event sender")
            return
        }
        
        methodHandler = SpeechMethodHandler(binaryMessenger: binaryMessenger, eventSender: eventSender)
        
        print("✅ [ContinuousSpeechPlugin] Plugin components initialized")
        logSystemInfo()
    }
    
    // MARK: - Lifecycle
    
    deinit {
        cleanup()
        print("🗑️ [ContinuousSpeechPlugin] Plugin deallocated")
    }
    
    private func cleanup() {
        print("🧹 [ContinuousSpeechPlugin] Cleaning up plugin...")
        
        methodHandler = nil
        eventSender = nil
        
        print("✅ [ContinuousSpeechPlugin] Cleanup completed")
    }
    
    // MARK: - System Information
    
    private func logSystemInfo() {
        let systemInfo = getSystemInfo()
        print("📱 [ContinuousSpeechPlugin] System Info: \(systemInfo)")
        
        // Send system info to Flutter for debugging
        eventSender?.sendDebugInfo(systemInfo)
    }
    
    private func getSystemInfo() -> [String: Any] {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        
        var info: [String: Any] = [
            "platform": "iOS",
            "systemVersion": device.systemVersion,
            "deviceModel": device.model,
            "deviceName": device.name,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "pluginVersion": "1.0.0"
        ]
        
        // Add iOS version-specific capabilities
        if #available(iOS 13.0, *) {
            info["supportsOnDeviceRecognition"] = true
        } else {
            info["supportsOnDeviceRecognition"] = false
        }
        
        if #available(iOS 14.0, *) {
            info["supportsAdvancedRecognition"] = true
        } else {
            info["supportsAdvancedRecognition"] = false
        }
        
        return info
    }
    
    // MARK: - Public Interface (for debugging)
    
    /// Get current plugin status for debugging
    public var debugInfo: [String: Any] {
        return [
            "methodHandlerActive": methodHandler != nil,
            "eventSenderActive": eventSender != nil,
            "eventChannelListening": eventSender?.isListening ?? false,
            "systemInfo": getSystemInfo()
        ]
    }
}

// MARK: - Version Compatibility

@available(iOS 10.0, *)
extension ContinuousSpeechPlugin {
    
    /// Check if current iOS version supports all features
    var isFullySupported: Bool {
        if #available(iOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
    
    /// Get list of supported features for current iOS version
    var supportedFeatures: [String] {
        var features = ["basicRecognition", "partialResults"]
        
        if #available(iOS 13.0, *) {
            features.append("onDeviceRecognition")
        }
        
        if #available(iOS 14.0, *) {
            features.append("advancedAudioProcessing")
        }
        
        if #available(iOS 15.0, *) {
            features.append("enhancedAccuracy")
        }
        
        return features
    }
}
