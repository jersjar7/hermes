// ios/Runner/Speech/Recognition/SpeechRecognitionManager.swift

import Foundation
import Speech
import AVFoundation

/// Delegate protocol for speech recognition events
@available(iOS 16.0, *)
protocol SpeechRecognitionManagerDelegate: AnyObject {
    func speechManager(_ manager: SpeechRecognitionManager, didReceivePartialResult text: String, confidence: Double)
    func speechManager(_ manager: SpeechRecognitionManager, didReceiveFinalResult text: String, confidence: Double)
    func speechManager(_ manager: SpeechRecognitionManager, didChangeStatus status: SpeechRecognitionStatus)
    func speechManager(_ manager: SpeechRecognitionManager, didEncounterError error: Error)
}

/// Core speech recognition manager that coordinates all recognition components
/// Delegates specific responsibilities to specialized managers
@available(iOS 16.0, *)
class SpeechRecognitionManager {
    
    // MARK: - Properties
    
    weak var delegate: SpeechRecognitionManagerDelegate?
    private var config: SpeechRecognitionConfig
    
    // Component managers
    private let permissionManager: SpeechPermissionManager
    private let audioSessionManager: AudioSessionManager
    
    // Speech recognition components
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // State management
    private var _status: SpeechRecognitionStatus = .idle {
        didSet {
            if _status != oldValue {
                print("🎙️ [SpeechManager] Status: \(oldValue.shortDescription) → \(_status.shortDescription)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.speechManager(self, didChangeStatus: self._status)
                }
            }
        }
    }
    
    var status: SpeechRecognitionStatus {
        return _status
    }
    
    // Expose current config for external access
    var currentConfig: SpeechRecognitionConfig {
        return config
    }
    
    // MARK: - Initialization
    
    init(config: SpeechRecognitionConfig = .default, delegate: SpeechRecognitionManagerDelegate? = nil) {
        self.config = config.validated()
        self.delegate = delegate
        
        // Initialize component managers
        self.permissionManager = SpeechPermissionManager()
        self.audioSessionManager = AudioSessionManager(config: self.config)
        
        print("🎙️ [SpeechManager] Initialized with locale: \(self.config.locale)")
    }
    
    deinit {
        stopRecognition()
        print("🗑️ [SpeechManager] Deallocated")
    }
    
    // MARK: - Public Interface
    
    /// Check if speech recognition is available for current configuration
    func isAvailable() -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: config.locale)) else {
            print("❌ [SpeechManager] Speech recognizer not available for locale: \(config.locale)")
            return false
        }
        
        guard recognizer.isAvailable else {
            print("❌ [SpeechManager] Speech recognizer not currently available")
            return false
        }
        
        return true
    }
    
    /// Request necessary permissions for speech recognition
    func requestPermissions() async -> Bool {
        return await permissionManager.requestAllPermissions()
    }
    
    /// Start continuous speech recognition
    func startRecognition() async throws {
        print("🚀 [SpeechManager] Starting recognition...")
        
        guard _status.canStart else {
            print("⚠️ [SpeechManager] Cannot start from current status: \(_status.shortDescription)")
            return
        }
        
        _status = .starting
        
        do {
            // Validate permissions
            let validationResult = permissionManager.validatePermissions()
            guard validationResult.isSuccess else {
                throw SpeechRecognitionError.permissionDenied(validationResult.errorMessage ?? "Permission denied")
            }
            
            // Setup components
            try await setupRecognitionComponents()
            
            _status = .listening
            print("✅ [SpeechManager] Recognition started successfully")
            
        } catch {
            _status = .error(error.localizedDescription)
            print("❌ [SpeechManager] Failed to start recognition: \(error)")
            throw error
        }
    }
    
    /// Stop speech recognition
    func stopRecognition() {
        print("🛑 [SpeechManager] Stopping recognition...")
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up recognition components
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        speechRecognizer = nil
        
        // Clean up audio session
        audioSessionManager.cleanup()
        
        _status = .stopped
        print("✅ [SpeechManager] Recognition stopped")
    }
    
    /// Update configuration (requires restart if currently active)
    func updateConfig(_ newConfig: SpeechRecognitionConfig) {
        let wasActive = _status.isActive
        
        if wasActive {
            stopRecognition()
        }
        
        config = newConfig.validated()
        print("🔧 [SpeechManager] Configuration updated")
        
        if wasActive {
            Task {
                try? await startRecognition()
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupRecognitionComponents() async throws {
        // Setup audio session
        try audioSessionManager.setupAudioSession()
        try audioSessionManager.optimizeForSpeechRecognition()
        
        // Create speech recognizer
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: config.locale)) else {
            throw SpeechRecognitionError.recognizerUnavailable(config.locale)
        }
        
        guard recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }
        
        speechRecognizer = recognizer
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.requestCreationFailed
        }
        
        // Configure request
        recognitionRequest.requiresOnDeviceRecognition = config.onDeviceRecognition && recognizer.supportsOnDeviceRecognition
        recognitionRequest.shouldReportPartialResults = config.partialResults
        
        // Setup audio engine
        try setupAudioEngine(with: recognitionRequest)
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
    }
    
    private func setupAudioEngine(with request: SFSpeechAudioBufferRecognitionRequest) throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap with configured buffer size
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(config.audioQuality.bufferSize), format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("❌ [SpeechManager] Recognition error: \(error)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.speechManager(self, didEncounterError: error)
            }
            return
        }
        
        guard let result = result else { return }
        
        let transcript = result.bestTranscription.formattedString
        let confidence = result.bestTranscription.segments.last?.confidence ?? 1.0
        let isFinal = result.isFinal
        
        // Update status
        if _status == .listening {
            _status = .processing
        }
        
        // Send result to delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isFinal {
                self.delegate?.speechManager(self, didReceiveFinalResult: transcript, confidence: Double(confidence))
                // Return to listening state after final result
                self._status = .listening
            } else {
                self.delegate?.speechManager(self, didReceivePartialResult: transcript, confidence: Double(confidence))
            }
        }
    }
}

// MARK: - Debug Support

@available(iOS 16.0, *)
extension SpeechRecognitionManager {
    
    /// Get comprehensive debug information
    var debugInfo: [String: Any] {
        return [
            "status": _status.description,
            "isActive": _status.isActive,
            "config": config.toDictionary(),
            "permissions": permissionManager.getPermissionStatusDescription(),
            "audioSession": audioSessionManager.debugInfo,
            "recognizerAvailable": isAvailable()
        ]
    }
}
