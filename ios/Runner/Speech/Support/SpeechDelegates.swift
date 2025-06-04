// ios/Runner/Speech/Support/SpeechDelegates.swift

import Foundation

// MARK: - Base Protocol Definitions

/// Base protocol for all speech recognition delegates
/// Provides common error handling interface
protocol SpeechRecognitionBaseDelegate: AnyObject {
    func speechRecognition(didEncounterError error: SpeechRecognitionError)
}

/// Protocol for receiving speech recognition status updates
protocol SpeechRecognitionStatusDelegate: AnyObject {
    func speechRecognition(didChangeStatus status: String, details: [String: Any]?)
}

/// Protocol for lifecycle events in speech recognition components
protocol SpeechRecognitionLifecycleDelegate: AnyObject {
    func speechRecognitionDidInitialize()
    func speechRecognitionDidStart()
    func speechRecognitionDidStop()
    func speechRecognitionDidCleanup()
}

// MARK: - Result Processing Protocols

/// Protocol for handling partial and final speech recognition results
protocol SpeechRecognitionResultDelegate: AnyObject {
    func speechRecognition(didReceivePartialResult text: String, confidence: Double, metadata: [String: Any]?)
    func speechRecognition(didReceiveFinalResult text: String, confidence: Double, metadata: [String: Any]?)
}

/// Protocol for handling sentence detection events
protocol SentenceDetectionDelegate: AnyObject {
    func sentenceDetection(didDetectPartial text: String)
    func sentenceDetection(didFinalizeSentence text: String, reason: String, metadata: [String: Any]?)
    func sentenceDetection(didEncounterError error: SpeechRecognitionError)
}

/// Protocol for handling audio processing events
protocol AudioProcessingDelegate: AnyObject {
    func audioProcessing(didSetupSession info: [String: Any])
    func audioProcessing(didOptimizeSettings settings: [String: Any])
    func audioProcessing(didDetectRouteChange route: String)
    func audioProcessing(didEncounterError error: SpeechRecognitionError)
}

// MARK: - Timer Management Protocols

/// Protocol for timer-based events in sentence detection
protocol TimerEventDelegate: AnyObject {
    func timerEvent(didTriggerStabilityTimeout duration: TimeInterval)
    func timerEvent(didTriggerMaxDurationTimeout duration: TimeInterval)
    func timerEvent(didReset timerType: String)
}

/// Protocol for monitoring timer state
protocol TimerStateDelegate: AnyObject {
    func timerState(didChange isActive: Bool, timerType: String, remainingTime: TimeInterval?)
}

// MARK: - Permission Management Protocols

/// Protocol for permission request events
protocol PermissionDelegate: AnyObject {
    func permission(didRequest type: String)
    func permission(didReceiveResult type: String, granted: Bool)
    func permission(didFailRequest type: String, error: SpeechRecognitionError)
}

/// Protocol for permission validation events
protocol PermissionValidationDelegate: AnyObject {
    func permissionValidation(didComplete result: Bool, details: [String: Any])
    func permissionValidation(didFail error: SpeechRecognitionError)
}

// MARK: - Plugin Communication Protocols

/// Protocol for Flutter method channel events
protocol FlutterMethodDelegate: AnyObject {
    func flutterMethod(didReceiveCall method: String, arguments: [String: Any]?)
    func flutterMethod(didSendResult method: String, result: Any?)
    func flutterMethod(didSendError method: String, error: SpeechRecognitionError)
}

/// Protocol for Flutter event channel events
protocol FlutterEventDelegate: AnyObject {
    func flutterEvent(didSendResult event: [String: Any])
    func flutterEvent(didSendError error: SpeechRecognitionError)
    func flutterEvent(didChangeListenerStatus isListening: Bool)
}

// MARK: - Configuration Protocols

/// Protocol for configuration updates
protocol ConfigurationDelegate: AnyObject {
    func configuration(didUpdate config: [String: Any], component: String)
    func configuration(didValidate config: [String: Any], isValid: Bool, errors: [String])
}

/// Protocol for runtime configuration changes
protocol RuntimeConfigurationDelegate: AnyObject {
    func runtimeConfiguration(shouldRestart component: String, reason: String)
    func runtimeConfiguration(didApplyChanges component: String, success: Bool)
}

// MARK: - Debugging and Monitoring Protocols

/// Protocol for debug information collection
protocol DebugInfoDelegate: AnyObject {
    func debugInfo(didCollect info: [String: Any], component: String)
    func debugInfo(didRequest component: String) -> [String: Any]
}

/// Protocol for performance monitoring
protocol PerformanceMonitorDelegate: AnyObject {
    func performanceMonitor(didMeasure metric: String, value: Double, component: String)
    func performanceMonitor(didDetectIssue issue: String, severity: ErrorSeverity, component: String)
}

// MARK: - Composite Delegate Protocols

/// Comprehensive delegate for speech recognition components
/// Combines multiple protocols for full-featured delegates
protocol ComprehensiveSpeechDelegate: SpeechRecognitionBaseDelegate,
                                       SpeechRecognitionStatusDelegate,
                                       SpeechRecognitionResultDelegate,
                                       SentenceDetectionDelegate {
    // Inherits all methods from component protocols
}

/// Plugin-level delegate combining all Flutter communication protocols
protocol PluginDelegate: FlutterMethodDelegate,
                         FlutterEventDelegate,
                         SpeechRecognitionStatusDelegate,
                         DebugInfoDelegate {
    // Inherits all methods from component protocols
}

/// Manager-level delegate for coordinating all speech recognition components
protocol SpeechManagerDelegate: SpeechRecognitionLifecycleDelegate,
                                SpeechRecognitionResultDelegate,
                                AudioProcessingDelegate,
                                PermissionDelegate,
                                ConfigurationDelegate {
    // Inherits all methods from component protocols
}

// MARK: - Protocol Extension Helpers

/// Extension providing default implementations for optional delegate methods
extension SpeechRecognitionBaseDelegate {
    func speechRecognition(didEncounterError error: SpeechRecognitionError) {
        speechError("Unhandled speech recognition error", component: .recognition, error: error)
    }
}

extension SpeechRecognitionStatusDelegate {
    func speechRecognition(didChangeStatus status: String, details: [String: Any]?) {
        speechInfo("Status changed: \(status)", component: .recognition)
    }
}

extension SpeechRecognitionLifecycleDelegate {
    func speechRecognitionDidInitialize() {
        speechInfo("Speech recognition initialized", component: .recognition)
    }
    
    func speechRecognitionDidStart() {
        speechInfo("Speech recognition started", component: .recognition)
    }
    
    func speechRecognitionDidStop() {
        speechInfo("Speech recognition stopped", component: .recognition)
    }
    
    func speechRecognitionDidCleanup() {
        speechInfo("Speech recognition cleaned up", component: .recognition)
    }
}

extension DebugInfoDelegate {
    func debugInfo(didCollect info: [String: Any], component: String) {
        speechDebug("Debug info collected for \(component)", component: .plugin)
    }
    
    func debugInfo(didRequest component: String) -> [String: Any] {
        return ["component": component, "timestamp": Date().timeIntervalSince1970]
    }
}

// MARK: - Delegate Helper Classes

/// Helper class for managing weak delegate collections
class WeakDelegateCollection<T: AnyObject> {
    private var delegates: [WeakWrapper<T>] = []
    
    func add(_ delegate: T) {
        cleanupDeallocatedDelegates()
        delegates.append(WeakWrapper(delegate))
    }
    
    func remove(_ delegate: T) {
        delegates.removeAll { $0.value === delegate }
    }
    
    func forEach(_ action: (T) -> Void) {
        cleanupDeallocatedDelegates()
        delegates.compactMap { $0.value }.forEach(action)
    }
    
    private func cleanupDeallocatedDelegates() {
        delegates.removeAll { $0.value == nil }
    }
    
    var count: Int {
        cleanupDeallocatedDelegates()
        return delegates.count
    }
}

/// Weak wrapper for delegate references
private class WeakWrapper<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}

/// Delegate multiplexer for broadcasting events to multiple delegates
class DelegateMultiplexer<T: AnyObject> {
    private let delegates = WeakDelegateCollection<T>()
    
    func addDelegate(_ delegate: T) {
        delegates.add(delegate)
    }
    
    func removeDelegate(_ delegate: T) {
        delegates.remove(delegate)
    }
    
    func broadcast(_ action: (T) -> Void) {
        delegates.forEach(action)
    }
    
    var delegateCount: Int {
        return delegates.count
    }
}
