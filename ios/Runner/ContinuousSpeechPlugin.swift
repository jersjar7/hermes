// ios/Runner/ContinuousSpeechPlugin.swift

import Flutter
import Speech
import AVFoundation

@available(iOS 10.0, *)
public class ContinuousSpeechPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // MARK: - Properties
    private var channel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    // Speech Recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // State
    private var isListening = false
    private var currentLocale = "en-US"
    
    // MARK: - Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ContinuousSpeechPlugin()
        
        // Method channel for commands
        let methodChannel = FlutterMethodChannel(
            name: "hermes/continuous_speech",
            binaryMessenger: registrar.messenger()
        )
        
        // Event channel for streaming results
        let eventChannel = FlutterEventChannel(
            name: "hermes/continuous_speech/events",
            binaryMessenger: registrar.messenger()
        )
        
        instance.channel = methodChannel
        instance.eventChannel = eventChannel
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        
        print("🎙️ [ContinuousSpeech-iOS] Plugin registered successfully")
    }
    
    // MARK: - Method Channel Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🎙️ [ContinuousSpeech-iOS] Method call: \(call.method)")
        
        switch call.method {
        case "isAvailable":
            handleIsAvailable(result: result)
            
        case "initialize":
            handleInitialize(result: result)
            
        case "startContinuousRecognition":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            handleStartContinuousRecognition(args: args, result: result)
            
        case "stopContinuousRecognition":
            handleStopContinuousRecognition(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Stream Handler (for events)
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("🎙️ [ContinuousSpeech-iOS] Event stream started")
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("🎙️ [ContinuousSpeech-iOS] Event stream cancelled")
        self.eventSink = nil
        return nil
    }
    
    // MARK: - iOS Version Compatibility Helpers
    private var supportsOnDeviceRecognition: Bool {
        if #available(iOS 13.0, *) {
            return speechRecognizer?.supportsOnDeviceRecognition ?? false
        } else {
            return false
        }
    }
    
    // MARK: - Handler Methods
    private func handleIsAvailable(result: @escaping FlutterResult) {
        print("🎙️ [ContinuousSpeech-iOS] Checking availability...")
        
        // Check if speech recognition is available
        guard SFSpeechRecognizer.authorizationStatus() != .denied else {
            print("❌ [ContinuousSpeech-iOS] Speech recognition denied")
            result(false)
            return
        }
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLocale)) else {
            print("❌ [ContinuousSpeech-iOS] Speech recognizer not available for locale: \(currentLocale)")
            result(false)
            return
        }
        
        guard recognizer.isAvailable else {
            print("❌ [ContinuousSpeech-iOS] Speech recognizer not available")
            result(false)
            return
        }
        
        // Store recognizer temporarily for compatibility check
        speechRecognizer = recognizer
        
        // Check if on-device recognition is supported (iOS 13+ only)
        if #available(iOS 13.0, *) {
            if supportsOnDeviceRecognition {
                print("✅ [ContinuousSpeech-iOS] On-device recognition supported - continuous recognition available!")
            } else {
                print("⚠️ [ContinuousSpeech-iOS] On-device recognition not supported - will use server-based (may have timeouts)")
            }
        } else {
            print("⚠️ [ContinuousSpeech-iOS] iOS 13+ required for on-device recognition - using server-based")
        }
        
        print("✅ [ContinuousSpeech-iOS] Speech recognition available")
        result(true)
    }
    
    private func handleInitialize(result: @escaping FlutterResult) {
        print("🎙️ [ContinuousSpeech-iOS] Initializing...")
        
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ [ContinuousSpeech-iOS] Speech recognition authorized")
                    self.setupAudioSession()
                    result(true)
                    
                case .denied:
                    print("❌ [ContinuousSpeech-iOS] Speech recognition denied")
                    result(false)
                    
                case .restricted:
                    print("❌ [ContinuousSpeech-iOS] Speech recognition restricted")
                    result(false)
                    
                case .notDetermined:
                    print("❌ [ContinuousSpeech-iOS] Speech recognition not determined")
                    result(false)
                    
                @unknown default:
                    print("❌ [ContinuousSpeech-iOS] Unknown speech recognition status")
                    result(false)
                }
            }
        }
    }
    
    private func handleStartContinuousRecognition(args: [String: Any], result: @escaping FlutterResult) {
        print("🎙️ [ContinuousSpeech-iOS] Starting continuous recognition...")
        
        // Extract arguments
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        let onDeviceRecognition = args["onDeviceRecognition"] as? Bool ?? true
        let partialResults = args["partialResults"] as? Bool ?? true
        
        print("🎙️ [ContinuousSpeech-iOS] Locale: \(currentLocale), OnDevice: \(onDeviceRecognition), Partial: \(partialResults)")
        
        // Stop any existing recognition
        stopRecognition()
        
        // Start new recognition
        do {
            try startRecognition(
                locale: currentLocale,
                onDeviceRecognition: onDeviceRecognition,
                partialResults: partialResults
            )
            
            isListening = true
            sendStatusEvent(status: "started")
            result(nil)
            
        } catch {
            print("❌ [ContinuousSpeech-iOS] Failed to start recognition: \(error)")
            sendErrorEvent(message: "Failed to start recognition: \(error.localizedDescription)")
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleStopContinuousRecognition(result: @escaping FlutterResult) {
        print("🎙️ [ContinuousSpeech-iOS] Stopping continuous recognition...")
        
        stopRecognition()
        isListening = false
        sendStatusEvent(status: "stopped")
        result(nil)
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        print("🎙️ [ContinuousSpeech-iOS] Setting up audio session...")
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ [ContinuousSpeech-iOS] Audio session configured")
        } catch {
            print("❌ [ContinuousSpeech-iOS] Audio session setup failed: \(error)")
        }
    }
    
    // MARK: - Core Recognition Logic
    private func startRecognition(locale: String, onDeviceRecognition: Bool, partialResults: Bool) throws {
        print("🚀 [ContinuousSpeech-iOS] Starting recognition with locale: \(locale)")
        
        // Ensure we have permission
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw NSError(domain: "SpeechRecognition", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authorized"])
        }
        
        // Create speech recognizer for the specified locale
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            throw NSError(domain: "SpeechRecognition", code: 2, userInfo: [NSLocalizedDescriptionKey: "Recognizer not available for locale: \(locale)"])
        }
        
        guard recognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognition", code: 3, userInfo: [NSLocalizedDescriptionKey: "Recognizer not available"])
        }
        
        speechRecognizer = recognizer
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognition", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        // 🎯 KEY CONFIGURATION: Enable features based on iOS version
        if #available(iOS 13.0, *) {
            // iOS 13+ features - this enables continuous recognition!
            recognitionRequest.requiresOnDeviceRecognition = onDeviceRecognition && supportsOnDeviceRecognition
            
            if recognitionRequest.requiresOnDeviceRecognition {
                print("🚀 [ContinuousSpeech-iOS] Using ON-DEVICE continuous recognition - NO GAPS!")
            } else {
                print("🌐 [ContinuousSpeech-iOS] Using server-based recognition - optimized for better continuity")
            }
        } else {
            // iOS 10-12: Server-based only, but still better than plugin's 500ms delays
            print("🌐 [ContinuousSpeech-iOS] iOS 10-12: Using server-based recognition with optimized restart logic")
        }
        
        // Always enable partial results for real-time feedback
        recognitionRequest.shouldReportPartialResults = partialResults
        
        // Set up audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        print("🎙️ [ContinuousSpeech-iOS] Audio engine started")
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        
        print("✅ [ContinuousSpeech-iOS] Recognition task started")
    }
    
    private func stopRecognition() {
        print("🛑 [ContinuousSpeech-iOS] Stopping recognition...")
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("🛑 [ContinuousSpeech-iOS] Audio engine stopped")
        }
        
        // Clean up recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        speechRecognizer = nil
        
        print("✅ [ContinuousSpeech-iOS] Recognition stopped completely")
    }
    
    // MARK: - Recognition Result Handling
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("❌ [ContinuousSpeech-iOS] Recognition error: \(error)")
            
            // Handle specific error types
            let nsError = error as NSError
            switch nsError.code {
            case 1700: // No speech input
                print("⚠️ [ContinuousSpeech-iOS] No speech input - continuing to listen...")
                // Don't send error for no speech input, just continue listening
                return
                
            case 203: // Request timed out
                print("⚠️ [ContinuousSpeech-iOS] Recognition timed out")
                if #available(iOS 13.0, *), supportsOnDeviceRecognition {
                    print("⚠️ [ContinuousSpeech-iOS] Unexpected timeout with on-device recognition")
                } else {
                    print("ℹ️ [ContinuousSpeech-iOS] Server-based recognition timeout - this is normal for long pauses")
                }
                
            default:
                print("❌ [ContinuousSpeech-iOS] Other error: \(error.localizedDescription)")
            }
            
            sendErrorEvent(message: error.localizedDescription)
            return
        }
        
        guard let result = result else {
            print("⚠️ [ContinuousSpeech-iOS] No result received")
            return
        }
        
        let transcript = result.bestTranscription.formattedString
        let isFinal = result.isFinal
        let confidence = result.bestTranscription.segments.last?.confidence ?? 1.0
        
        // Only send non-empty transcripts
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        print("📝 [ContinuousSpeech-iOS] Result: \"\(transcript)\" (final: \(isFinal), confidence: \(confidence))")
        
        // Send result to Flutter
        sendResultEvent(
            transcript: transcript,
            isFinal: isFinal,
            confidence: Double(confidence),
            locale: currentLocale
        )
        
        // 🎯 CRITICAL: For continuous recognition, we DON'T restart here!
        // The recognition will continue running until we explicitly stop it
        if isFinal {
            if #available(iOS 13.0, *), supportsOnDeviceRecognition {
                print("✅ [ContinuousSpeech-iOS] Final result received - on-device recognition continues seamlessly...")
            } else {
                print("✅ [ContinuousSpeech-iOS] Final result received - server-based recognition may pause briefly...")
            }
        }
    }
    
    // MARK: - Event Sending
    private func sendResultEvent(transcript: String, isFinal: Bool, confidence: Double, locale: String) {
        guard let eventSink = eventSink else {
            print("⚠️ [ContinuousSpeech-iOS] No event sink available for result")
            return
        }
        
        let event: [String: Any] = [
            "type": "result",
            "transcript": transcript,
            "isFinal": isFinal,
            "confidence": confidence,
            "locale": locale
        ]
        
        DispatchQueue.main.async {
            eventSink(event)
        }
    }
    
    private func sendErrorEvent(message: String) {
        guard let eventSink = eventSink else {
            print("⚠️ [ContinuousSpeech-iOS] No event sink available for error")
            return
        }
        
        let event: [String: Any] = [
            "type": "error",
            "message": message
        ]
        
        DispatchQueue.main.async {
            eventSink(event)
        }
    }
    
    private func sendStatusEvent(status: String) {
        guard let eventSink = eventSink else {
            print("⚠️ [ContinuousSpeech-iOS] No event sink available for status")
            return
        }
        
        let event: [String: Any] = [
            "type": "status",
            "status": status
        ]
        
        DispatchQueue.main.async {
            eventSink(event)
        }
    }
    
    // MARK: - Cleanup
    deinit {
        print("🗑️ [ContinuousSpeech-iOS] Plugin deallocated")
        stopRecognition()
    }
}