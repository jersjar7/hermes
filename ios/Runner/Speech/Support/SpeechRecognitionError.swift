// ios/Runner/Speech/Support/SpeechRecognitionError.swift

import Foundation

/// Comprehensive error types for speech recognition system
/// Provides detailed error information for debugging and user feedback
enum SpeechRecognitionError: Error {
    
    // MARK: - Permission Errors
    case permissionDenied(String)
    case permissionRestricted
    case permissionNotDetermined
    case microphonePermissionDenied
    
    // MARK: - Recognition Errors
    case recognizerUnavailable(String)
    case recognizerNotAvailable
    case recognitionTaskFailed(Error)
    case requestCreationFailed
    case invalidConfiguration(String)
    
    // MARK: - Audio Errors
    case audioEngineFailure(Error)
    case audioSessionSetupFailed(Error)
    case audioInputUnavailable
    case audioFormatNotSupported
    
    // MARK: - Sentence Detection Errors
    case sentenceDetectionFailed(Error)
    case invalidTextInput
    case timerManagerFailure(String)
    case patternMatchingFailed
    
    // MARK: - Plugin Communication Errors
    case methodChannelError(String)
    case eventChannelError(String)
    case flutterCommunicationFailed
    case invalidMethodArguments(String)
    
    // MARK: - System Errors
    case systemResourcesUnavailable
    case insufficientMemory
    case networkUnavailable
    case deviceNotSupported(String)
}

// MARK: - LocalizedError Implementation

extension SpeechRecognitionError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        // Permission Errors
        case .permissionDenied(let details):
            return "Speech recognition permission denied: \(details)"
        case .permissionRestricted:
            return "Speech recognition is restricted by device policy"
        case .permissionNotDetermined:
            return "Speech recognition permission not requested"
        case .microphonePermissionDenied:
            return "Microphone access denied"
            
        // Recognition Errors
        case .recognizerUnavailable(let locale):
            return "Speech recognizer not available for locale: \(locale)"
        case .recognizerNotAvailable:
            return "Speech recognizer temporarily unavailable"
        case .recognitionTaskFailed(let error):
            return "Recognition task failed: \(error.localizedDescription)"
        case .requestCreationFailed:
            return "Failed to create speech recognition request"
        case .invalidConfiguration(let details):
            return "Invalid speech recognition configuration: \(details)"
            
        // Audio Errors
        case .audioEngineFailure(let error):
            return "Audio engine failure: \(error.localizedDescription)"
        case .audioSessionSetupFailed(let error):
            return "Audio session setup failed: \(error.localizedDescription)"
        case .audioInputUnavailable:
            return "Audio input device unavailable"
        case .audioFormatNotSupported:
            return "Audio format not supported"
            
        // Sentence Detection Errors
        case .sentenceDetectionFailed(let error):
            return "Sentence detection failed: \(error.localizedDescription)"
        case .invalidTextInput:
            return "Invalid text input for sentence detection"
        case .timerManagerFailure(let details):
            return "Timer manager failure: \(details)"
        case .patternMatchingFailed:
            return "Pattern matching failed"
            
        // Plugin Communication Errors
        case .methodChannelError(let details):
            return "Method channel error: \(details)"
        case .eventChannelError(let details):
            return "Event channel error: \(details)"
        case .flutterCommunicationFailed:
            return "Flutter communication failed"
        case .invalidMethodArguments(let details):
            return "Invalid method arguments: \(details)"
            
        // System Errors
        case .systemResourcesUnavailable:
            return "System resources unavailable"
        case .insufficientMemory:
            return "Insufficient memory for speech recognition"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .deviceNotSupported(let details):
            return "Device not supported: \(details)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .permissionDenied, .permissionRestricted, .microphonePermissionDenied:
            return "The app doesn't have permission to access speech recognition or microphone"
        case .recognizerUnavailable, .recognizerNotAvailable:
            return "Speech recognition service is not available on this device or for this language"
        case .audioEngineFailure, .audioSessionSetupFailed, .audioInputUnavailable:
            return "Audio system is not working properly"
        case .systemResourcesUnavailable, .insufficientMemory:
            return "Device doesn't have enough resources for speech recognition"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied, .permissionRestricted, .microphonePermissionDenied:
            return "Go to Settings > Privacy & Security > Speech Recognition and enable access for this app"
        case .recognizerNotAvailable:
            return "Try again later when speech recognition service becomes available"
        case .recognizerUnavailable:
            return "Try selecting a different language or check if your device supports speech recognition"
        case .audioInputUnavailable:
            return "Check that your microphone is working and try again"
        case .insufficientMemory:
            return "Close other apps and try again"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        default:
            return "Try restarting the app or restarting your device"
        }
    }
}

// MARK: - Error Code Mapping

extension SpeechRecognitionError {
    
    /// Error code for Flutter communication
    var errorCode: String {
        switch self {
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .microphonePermissionDenied:
            return "PERMISSION_ERROR"
        case .recognizerUnavailable, .recognizerNotAvailable:
            return "RECOGNIZER_ERROR"
        case .recognitionTaskFailed, .requestCreationFailed:
            return "RECOGNITION_ERROR"
        case .invalidConfiguration:
            return "CONFIGURATION_ERROR"
        case .audioEngineFailure, .audioSessionSetupFailed, .audioInputUnavailable, .audioFormatNotSupported:
            return "AUDIO_ERROR"
        case .sentenceDetectionFailed, .invalidTextInput, .timerManagerFailure, .patternMatchingFailed:
            return "SENTENCE_DETECTION_ERROR"
        case .methodChannelError, .eventChannelError, .flutterCommunicationFailed, .invalidMethodArguments:
            return "COMMUNICATION_ERROR"
        case .systemResourcesUnavailable, .insufficientMemory, .networkUnavailable, .deviceNotSupported:
            return "SYSTEM_ERROR"
        }
    }
    
    /// Severity level for logging and error handling
    var severity: ErrorSeverity {
        switch self {
        case .permissionDenied, .permissionRestricted, .microphonePermissionDenied:
            return .critical
        case .recognizerUnavailable, .deviceNotSupported:
            return .high
        case .recognizerNotAvailable, .networkUnavailable:
            return .medium
        case .invalidConfiguration, .invalidMethodArguments, .invalidTextInput:
            return .low
        default:
            return .medium
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var emoji: String {
        switch self {
        case .low: return "⚠️"
        case .medium: return "🟡"
        case .high: return "🔴"
        case .critical: return "💥"
        }
    }
}

// MARK: - Error Factory

extension SpeechRecognitionError {
    
    /// Create error from system NSError
    static func fromSystemError(_ error: NSError, context: String = "") -> SpeechRecognitionError {
        let description = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        
        switch error.domain {
        case "kAFAssistantErrorDomain":
            return .recognitionTaskFailed(error)
        case "AVAudioSessionErrorDomain":
            return .audioSessionSetupFailed(error)
        case "AVAudioEngineErrorDomain":
            return .audioEngineFailure(error)
        default:
            return .systemResourcesUnavailable
        }
    }
    
    /// Create error from configuration validation
    static func configurationError(_ message: String) -> SpeechRecognitionError {
        return .invalidConfiguration(message)
    }
    
    /// Create error from Flutter method arguments
    static func methodArgumentsError(_ message: String) -> SpeechRecognitionError {
        return .invalidMethodArguments(message)
    }
}
