// ios/Runner/Speech/Plugin/SpeechEventSender.swift
// STEP 4: Enhanced event sender that sends pattern-confirmed results separately

import Flutter
import Foundation

/// Enhanced event sender that distinguishes between partial and pattern-confirmed results
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
        print("📡 [EventSender] Enhanced event channel initialized")
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
    
    // MARK: - Regular Speech Results (Partial Only)
    
    /// Send partial speech recognition result to Flutter
    func sendPartialResult(
        transcript: String,
        confidence: Double,
        locale: String
    ) {
        guard !transcript.isEmpty else {
            print("⚠️ [EventSender] Skipping empty partial transcript")
            return
        }
        
        let event: [String: Any] = [
            "type": "result",
            "transcript": transcript,
            "isFinal": false, // Always false for partial results
            "confidence": confidence,
            "locale": locale,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendEvent(event)
        print("📡 [EventSender] Sent PARTIAL: \"\(String(transcript.prefix(30)))...\" (confidence: \(confidence))")
    }
    
    // 🆕 NEW: Send pattern-confirmed complete sentence
    /// Send pattern-confirmed complete sentence to Flutter
    func sendPatternConfirmedSentence(
        transcript: String,
        confidence: Double,
        locale: String,
        reason: String
    ) {
        guard !transcript.isEmpty else {
            print("⚠️ [EventSender] Skipping empty confirmed transcript")
            return
        }
        
        let event: [String: Any] = [
            "type": "pattern_confirmed", // 🎯 DIFFERENT EVENT TYPE
            "transcript": transcript,
            "isFinal": true,
            "confidence": confidence,
            "locale": locale,
            "reason": reason,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendEvent(event)
        print("🎯 [EventSender] ✅ CONFIRMED SENTENCE: \"\(String(transcript.prefix(50)))...\" (reason: \(reason))")
    }
    
    // MARK: - Legacy Method (Keep for backward compatibility)
    
    /// Legacy method - will be treated as partial result
    func sendRecognitionResult(
        transcript: String,
        isFinal: Bool,
        confidence: Double,
        locale: String,
        reason: String? = nil
    ) {
        if isFinal {
            // 🚨 WARNING: This should not be used for final results anymore
            // Use sendPatternConfirmedSentence instead
            print("⚠️ [EventSender] WARNING: Using legacy sendRecognitionResult for final result. Use sendPatternConfirmedSentence instead.")
            
            if let reason = reason {
                sendPatternConfirmedSentence(
                    transcript: transcript,
                    confidence: confidence,
                    locale: locale,
                    reason: reason
                )
            } else {
                sendPatternConfirmedSentence(
                    transcript: transcript,
                    confidence: confidence,
                    locale: locale,
                    reason: "legacy"
                )
            }
        } else {
            sendPartialResult(
                transcript: transcript,
                confidence: confidence,
                locale: locale
            )
        }
    }
    
    // MARK: - Other Event Types
    
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
    
    /// Send debug information to Flutter
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
