// ios/Runner/Speech/Plugin/SpeechEventSender.swift

import Flutter
import Foundation

/// Handles Flutter event channel communication for speech recognition events
/// Responsible only for formatting and sending events to Flutter
class SpeechEventSender: NSObject, FlutterStreamHandler {
    
    // MARK: - Properties
    
    private var eventSink: FlutterEventSink?
    private let eventChannel: FlutterEventChannel
    
    // MARK: - Initialization
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        self.eventChannel = FlutterEventChannel(
            name: "hermes/continuous_speech/events",
            binaryMessenger: binaryMessenger
        )
        
        super.init()
        
        eventChannel.setStreamHandler(self)
        print("📡 [EventSender] Event channel initialized")
    }
    
    deinit {
        eventChannel.setStreamHandler(nil)
        print("📡 [EventSender] Event channel deallocated")
    }
    
    // MARK: - FlutterStreamHandler
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("📡 [EventSender] Flutter event stream started")
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("📡 [EventSender] Flutter event stream cancelled")
        self.eventSink = nil
        return nil
    }
    
    // MARK: - Public Event Methods
    
    /// Send speech recognition result to Flutter
    func sendRecognitionResult(
        transcript: String,
        isFinal: Bool,
        confidence: Double,
        locale: String,
        reason: String? = nil
    ) {
        guard !transcript.isEmpty else {
            print("⚠️ [EventSender] Skipping empty transcript")
            return
        }
        
        var event: [String: Any] = [
            "type": "result",
            "transcript": transcript,
            "isFinal": isFinal,
            "confidence": confidence,
            "locale": locale,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Add finalization reason for debugging
        if isFinal, let reason = reason {
            event["reason"] = reason
        }
        
        sendEvent(event)
        
        let finalText = isFinal ? "FINAL" : "PARTIAL"
        print("📡 [EventSender] Sent \(finalText): \"\(transcript.prefix(50))\" (confidence: \(confidence))")
    }
    
    /// Send status update to Flutter
    func sendStatusUpdate(_ status: String, details: [String: Any]? = nil) {
        var event: [String: Any] = [
            "type": "status",
            "status": status,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let details = details {
            event["details"] = details
        }
        
        sendEvent(event)
        print("📡 [EventSender] Status: \(status)")
    }
    
    /// Send error to Flutter
    func sendError(message: String, code: String? = nil, details: [String: Any]? = nil) {
        var event: [String: Any] = [
            "type": "error",
            "message": message,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let code = code {
            event["code"] = code
        }
        
        if let details = details {
            event["details"] = details
        }
        
        sendEvent(event)
        print("❌ [EventSender] Error: \(message)")
    }
    
    /// Send debug information to Flutter (useful for development)
    func sendDebugInfo(_ info: [String: Any]) {
        let event: [String: Any] = [
            "type": "debug",
            "info": info,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendEvent(event)
        print("🐛 [EventSender] Debug info sent")
    }
    
    // MARK: - Private Helpers
    
    private func sendEvent(_ event: [String: Any]) {
        guard let eventSink = eventSink else {
            print("⚠️ [EventSender] No event sink available, dropping event: \(event["type"] ?? "unknown")")
            return
        }
        
        DispatchQueue.main.async {
            eventSink(event)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if Flutter is listening for events
    var isListening: Bool {
        return eventSink != nil
    }
    
    /// Get event channel name for debugging
    var channelName: String {
        return "hermes/continuous_speech/events"
    }
}
