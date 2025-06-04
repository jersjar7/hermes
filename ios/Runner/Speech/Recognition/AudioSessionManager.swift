// ios/Runner/Speech/Recognition/AudioSessionManager.swift

import Foundation
import AVFoundation

/// Manages audio session configuration for speech recognition
/// Handles setup, activation, and cleanup of audio resources
class AudioSessionManager {
    
    // MARK: - Properties
    
    private let config: SpeechRecognitionConfig
    private var audioSession: AVAudioSession {
        return AVAudioSession.sharedInstance()
    }
    
    private var isSessionActive = false
    
    // MARK: - Initialization
    
    init(config: SpeechRecognitionConfig) {
        self.config = config
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Audio Session Management
    
    /// Setup and activate audio session for speech recognition
    func setupAudioSession() throws {
        print("🎧 [AudioManager] Setting up audio session...")
        
        do {
            // Configure audio session category and options
            try audioSession.setCategory(
                .record,
                mode: .measurement,
                options: [.duckOthers, .allowBluetooth]
            )
            
            // Set preferred sample rate based on quality
            try audioSession.setPreferredSampleRate(config.audioQuality.sampleRate)
            
            // Set preferred buffer duration for responsiveness
            let bufferDuration = TimeInterval(config.audioQuality.bufferSize) / config.audioQuality.sampleRate
            try audioSession.setPreferredIOBufferDuration(bufferDuration)
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            isSessionActive = true
            print("✅ [AudioManager] Audio session configured successfully")
            print("📊 [AudioManager] Sample rate: \(audioSession.sampleRate)Hz, Buffer: \(audioSession.ioBufferDuration)s")
            
        } catch {
            print("❌ [AudioManager] Failed to setup audio session: \(error)")
            throw AudioSessionError.setupFailed(error)
        }
    }
    
    /// Deactivate audio session
    func deactivateAudioSession() {
        guard isSessionActive else {
            print("⚠️ [AudioManager] Audio session not active, skipping deactivation")
            return
        }
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
            print("✅ [AudioManager] Audio session deactivated")
        } catch {
            print("❌ [AudioManager] Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Get current audio session information
    func getSessionInfo() -> [String: Any] {
        return [
            "category": audioSession.category.rawValue,
            "mode": audioSession.mode.rawValue,
            "sampleRate": audioSession.sampleRate,
            "ioBufferDuration": audioSession.ioBufferDuration,
            "inputGain": audioSession.inputGain,
            "isActive": isSessionActive,
            "isInputAvailable": audioSession.isInputAvailable,
            "inputNumberOfChannels": audioSession.inputNumberOfChannels
        ]
    }
    
    // MARK: - Audio Route Management
    
    /// Get current audio input route information
    func getCurrentAudioRoute() -> String {
        let currentRoute = audioSession.currentRoute
        let inputs = currentRoute.inputs.map { $0.portType.rawValue }
        return inputs.isEmpty ? "No input" : inputs.joined(separator: ", ")
    }
    
    /// Check if bluetooth audio is available
    var isBluetoothAvailable: Bool {
        let availableInputs = audioSession.availableInputs ?? []
        return availableInputs.contains { input in
            input.portType == .bluetoothHFP || input.portType == .bluetoothA2DP || input.portType == .bluetoothLE
        }
    }
    
    /// Check if wired headset is connected
    var isWiredHeadsetConnected: Bool {
        let currentRoute = audioSession.currentRoute
        return currentRoute.inputs.contains { input in
            input.portType == .headsetMic || input.portType == .wiredMicrophone
        }
    }
    
    // MARK: - Audio Quality Optimization
    
    /// Optimize audio settings for speech recognition
    func optimizeForSpeechRecognition() throws {
        guard isSessionActive else {
            throw AudioSessionError.sessionNotActive
        }
        
        do {
            // Enable noise suppression if supported and requested
            if config.enableNoiseSupression && audioSession.isInputGainSettable {
                // Set optimal input gain for speech
                try audioSession.setInputGain(0.8) // 80% gain for clear speech
                print("🔧 [AudioManager] Optimized input gain for speech recognition")
            }
            
            // Set preferred input port if multiple are available
            if let preferredInput = selectOptimalInputPort() {
                try audioSession.setPreferredInput(preferredInput)
                print("🔧 [AudioManager] Selected optimal input: \(preferredInput.portName)")
            }
            
        } catch {
            print("⚠️ [AudioManager] Failed to optimize audio settings: \(error)")
            // Don't throw - optimization is best effort
        }
    }
    
    private func selectOptimalInputPort() -> AVAudioSessionPortDescription? {
        let availableInputs = audioSession.availableInputs ?? []
        
        // Prefer wired headset microphone (best quality)
        if let headsetMic = availableInputs.first(where: { $0.portType == .headsetMic }) {
            return headsetMic
        }
        
        // Then prefer built-in microphone
        if let builtInMic = availableInputs.first(where: { $0.portType == .builtInMic }) {
            return builtInMic
        }
        
        // Finally, use any available input
        return availableInputs.first
    }
    
    // MARK: - Cleanup
    
    /// Clean up audio resources
    func cleanup() {
        print("🧹 [AudioManager] Cleaning up audio session")
        deactivateAudioSession()
    }
}

// MARK: - Error Types

extension AudioSessionManager {
    
    enum AudioSessionError: LocalizedError {
        case setupFailed(Error)
        case sessionNotActive
        case optimizationFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .setupFailed(let error):
                return "Audio session setup failed: \(error.localizedDescription)"
            case .sessionNotActive:
                return "Audio session is not active"
            case .optimizationFailed(let error):
                return "Audio optimization failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Debug Support

extension AudioSessionManager {
    
    /// Get comprehensive debug information
    var debugInfo: [String: Any] {
        var info = getSessionInfo()
        info["audioRoute"] = getCurrentAudioRoute()
        info["bluetoothAvailable"] = isBluetoothAvailable
        info["wiredHeadsetConnected"] = isWiredHeadsetConnected
        info["config"] = config.toDictionary()
        return info
    }
}
