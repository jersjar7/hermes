// ios/Runner/ContinuousSpeechPlugin.swift - Safe version with simple pause detection

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
    
    // ✨ SIMPLE: Pause Detection for Final Results (without complex audio monitoring)
    private var lastTranscript = ""
    private var finalizationTimer: Timer?
    private let finalizationDelay: TimeInterval = 2.0 // 2 seconds of no changes = final
    
    // MARK: - Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ContinuousSpeechPlugin()
        
        let methodChannel = FlutterMethodChannel(
            name: "hermes/continuous_speech",
            binaryMessenger: registrar.messenger()
        )
        
        let eventChannel = FlutterEventChannel(
            name: "hermes/continuous_speech/events",
            binaryMessenger: registrar.messenger()
        )
        
        instance.channel = methodChannel
        instance.eventChannel = eventChannel
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        
        print("🎙️ [ContinuousSpeech-iOS] Safe plugin with simple pause detection registered")
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
    
    // MARK: - Stream Handler
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
        
        speechRecognizer = recognizer
        print("✅ [ContinuousSpeech-iOS] Speech recognition available")
        result(true)
    }
    
    private func handleInitialize(result: @escaping FlutterResult) {
        print("🎙️ [ContinuousSpeech-iOS] Initializing...")
        
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
        
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        let onDeviceRecognition = args["onDeviceRecognition"] as? Bool ?? true
        let partialResults = args["partialResults"] as? Bool ?? true
        
        print("🎙️ [ContinuousSpeech-iOS] Locale: \(currentLocale), OnDevice: \(onDeviceRecognition), Partial: \(partialResults)")
        
        stopRecognition()
        
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
    
    // MARK: - SAFE: Core Recognition Logic (without complex audio monitoring)
    private func startRecognition(locale: String, onDeviceRecognition: Bool, partialResults: Bool) throws {
        print("🚀 [ContinuousSpeech-iOS] Starting SAFE recognition with simple pause detection")
        
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
        
        // Configure for continuous recognition
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = onDeviceRecognition && supportsOnDeviceRecognition
            print("🚀 [ContinuousSpeech-iOS] Using on-device: \(recognitionRequest.requiresOnDeviceRecognition)")
        }
        
        recognitionRequest.shouldReportPartialResults = partialResults
        
        // ✨ SAFE: Set up audio engine WITHOUT complex tap monitoring
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // SIMPLE: Install basic tap without audio level monitoring
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Reset state
        lastTranscript = ""
        
        print("🎙️ [ContinuousSpeech-iOS] SAFE audio engine started")
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleSafeRecognitionResult(result: result, error: error)
        }
        
        print("✅ [ContinuousSpeech-iOS] SAFE recognition with simple pause detection started")
    }
    
    // ✨ SAFE: Recognition Result Handling with Simple Timer-Based Finalization
    private func handleSafeRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("❌ [ContinuousSpeech-iOS] Recognition error: \(error)")
            sendErrorEvent(message: error.localizedDescription)
            return
        }
        
        guard let result = result else {
            print("⚠️ [ContinuousSpeech-iOS] No result received")
            return
        }
        
        let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalIsFinal = result.isFinal
        let confidence = result.bestTranscription.segments.last?.confidence ?? 1.0
        
        // Skip empty transcripts
        guard !transcript.isEmpty else { return }
        
        print("📝 [ContinuousSpeech-iOS] Result: \"\(transcript)\" (original final: \(originalIsFinal))")
        
        // ✨ SIMPLE FINALIZATION LOGIC
        let hasChanged = transcript != lastTranscript
        
        if hasChanged {
            // Cancel any pending finalization
            finalizationTimer?.invalidate()
            
            // Send as partial result
            sendResultEvent(
                transcript: transcript,
                isFinal: false,
                confidence: Double(confidence),
                locale: currentLocale
            )
            
            // Update last transcript
            lastTranscript = transcript
            
            // ✨ START SIMPLE FINALIZATION TIMER
            finalizationTimer = Timer.scheduledTimer(withTimeInterval: finalizationDelay, repeats: false) { [weak self] _ in
                self?.finalizeCurrentTranscript()
            }
            
            print("⏱️ [ContinuousSpeech-iOS] Started finalization timer for: \"\(transcript)\"")
        } else if originalIsFinal && !transcript.isEmpty {
            // iOS marked it as final, so finalize immediately
            finalizeTranscript(transcript, confidence: Double(confidence))
        }
    }
    
    // ✨ SIMPLE: Finalize Current Transcript
    private func finalizeCurrentTranscript() {
        guard !lastTranscript.isEmpty else { return }
        
        print("✅ [ContinuousSpeech-iOS] Auto-finalizing transcript: \"\(lastTranscript)\"")
        finalizeTranscript(lastTranscript, confidence: 1.0)
    }
    
    // ✨ SIMPLE: Send Final Transcript
    private func finalizeTranscript(_ transcript: String, confidence: Double) {
        // Cancel any pending finalization
        finalizationTimer?.invalidate()
        
        // Send as final result (this will have punctuation if iOS adds it)
        sendResultEvent(
            transcript: transcript,
            isFinal: true,
            confidence: confidence,
            locale: currentLocale
        )
        
        print("🏁 [ContinuousSpeech-iOS] Sent FINAL result: \"\(transcript)\"")
        
        // Reset for next segment
        lastTranscript = ""
    }
    
    // MARK: - Cleanup
    private func stopRecognition() {
        print("🛑 [ContinuousSpeech-iOS] Stopping SAFE recognition...")
        
        // Stop timer
        finalizationTimer?.invalidate()
        finalizationTimer = nil
        
        // Finalize any pending transcript
        if !lastTranscript.isEmpty {
            finalizeCurrentTranscript()
        }
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        speechRecognizer = nil
        
        // Reset state
        lastTranscript = ""
        
        print("✅ [ContinuousSpeech-iOS] SAFE recognition stopped")
    }
    
    // MARK: - Event Sending (unchanged)
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
        guard let eventSink = eventSink else { return }
        
        let event: [String: Any] = [
            "type": "error",
            "message": message
        ]
        
        DispatchQueue.main.async {
            eventSink(event)
        }
    }
    
    private func sendStatusEvent(status: String) {
        guard let eventSink = eventSink else { return }
        
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
        print("🗑️ [ContinuousSpeech-iOS] SAFE plugin deallocated")
        stopRecognition()
    }
}