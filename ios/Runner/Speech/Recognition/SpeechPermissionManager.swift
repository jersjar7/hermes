// ios/Runner/Speech/Recognition/SpeechPermissionManager.swift

import Foundation
import Speech
import AVFoundation

/// Manages speech recognition and microphone permissions
/// Provides clean async/await interface for permission handling
@available(iOS 10.0, *)
class SpeechPermissionManager {
    
    // MARK: - Permission Status
    
    /// Check current speech recognition permission status
    var speechPermissionStatus: SFSpeechRecognizerAuthorizationStatus {
        return SFSpeechRecognizer.authorizationStatus()
    }
    
    /// Check current microphone permission status
    var microphonePermissionStatus: AVAudioSession.RecordPermission {
        return AVAudioSession.sharedInstance().recordPermission
    }
    
    /// Check if speech recognition is authorized
    var isSpeechAuthorized: Bool {
        return speechPermissionStatus == .authorized
    }
    
    /// Check if microphone is authorized
    var isMicrophoneAuthorized: Bool {
        return microphonePermissionStatus == .granted
    }
    
    /// Check if both permissions are granted
    var areAllPermissionsGranted: Bool {
        return isSpeechAuthorized && isMicrophoneAuthorized
    }
    
    // MARK: - Permission Requests
    
    /// Request speech recognition permission
    func requestSpeechPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let granted = status == .authorized
                print("🔐 [PermissionManager] Speech permission: \(status) (granted: \(granted))")
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print("🎤 [PermissionManager] Microphone permission: \(granted)")
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Request both speech and microphone permissions
    func requestAllPermissions() async -> Bool {
        print("🔐 [PermissionManager] Requesting all permissions...")
        
        let speechGranted = await requestSpeechPermission()
        let microphoneGranted = await requestMicrophonePermission()
        
        let allGranted = speechGranted && microphoneGranted
        
        print("✅ [PermissionManager] All permissions granted: \(allGranted)")
        return allGranted
    }
    
    // MARK: - Permission Validation
    
    /// Validate permissions before starting recognition
    func validatePermissions() -> PermissionValidationResult {
        let speechStatus = speechPermissionStatus
        let microphoneStatus = microphonePermissionStatus
        
        // Check speech permission
        switch speechStatus {
        case .notDetermined:
            return .failure(.speechNotRequested)
        case .denied:
            return .failure(.speechDenied)
        case .restricted:
            return .failure(.speechRestricted)
        case .authorized:
            break // Continue to microphone check
        @unknown default:
            return .failure(.speechUnknown)
        }
        
        // Check microphone permission
        switch microphoneStatus {
        case .undetermined:
            return .failure(.microphoneNotRequested)
        case .denied:
            return .failure(.microphoneDenied)
        case .granted:
            break // All good
        @unknown default:
            return .failure(.microphoneUnknown)
        }
        
        return .success
    }
    
    // MARK: - Helper Methods
    
    /// Get user-friendly permission status description
    func getPermissionStatusDescription() -> String {
        let speechDesc = getSpeechPermissionDescription()
        let microphoneDesc = getMicrophonePermissionDescription()
        
        return "Speech: \(speechDesc), Microphone: \(microphoneDesc)"
    }
    
    private func getSpeechPermissionDescription() -> String {
        switch speechPermissionStatus {
        case .notDetermined: return "Not Requested"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
    
    private func getMicrophonePermissionDescription() -> String {
        switch microphonePermissionStatus {
        case .undetermined: return "Not Requested"
        case .denied: return "Denied"
        case .granted: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Permission Validation Result

extension SpeechPermissionManager {
    
    enum PermissionValidationResult {
        case success
        case failure(PermissionError)
        
        var isSuccess: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .success: return nil
            case .failure(let error): return error.description
            }
        }
    }
    
    enum PermissionError: LocalizedError {
        case speechNotRequested
        case speechDenied
        case speechRestricted
        case speechUnknown
        case microphoneNotRequested
        case microphoneDenied
        case microphoneUnknown
        
        var description: String {
            switch self {
            case .speechNotRequested:
                return "Speech recognition permission not requested"
            case .speechDenied:
                return "Speech recognition permission denied"
            case .speechRestricted:
                return "Speech recognition restricted by device policy"
            case .speechUnknown:
                return "Speech recognition permission status unknown"
            case .microphoneNotRequested:
                return "Microphone permission not requested"
            case .microphoneDenied:
                return "Microphone permission denied"
            case .microphoneUnknown:
                return "Microphone permission status unknown"
            }
        }
        
        var errorDescription: String? {
            return description
        }
    }
}
