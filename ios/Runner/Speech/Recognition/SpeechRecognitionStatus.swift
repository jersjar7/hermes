// ios/Runner/Speech/Recognition/SpeechRecognitionStatus.swift

import Foundation

/// Speech recognition status with associated data
/// Provides clear state management and transitions
enum SpeechRecognitionStatus {
    case idle
    case starting
    case listening
    case processing
    case stopped
    case error(String)
    
    // MARK: - Status Properties
    
    /// Human-readable description
    var description: String {
        switch self {
        case .idle:
            return "idle"
        case .starting:
            return "starting"
        case .listening:
            return "listening"
        case .processing:
            return "processing"
        case .stopped:
            return "stopped"
        case .error(let message):
            return "error: \(message)"
        }
    }
    
    /// Short status string for APIs
    var shortDescription: String {
        switch self {
        case .idle: return "idle"
        case .starting: return "starting"
        case .listening: return "listening"
        case .processing: return "processing"
        case .stopped: return "stopped"
        case .error: return "error"
        }
    }
    
    /// Whether recognition is currently active
    var isActive: Bool {
        switch self {
        case .listening, .processing:
            return true
        case .idle, .starting, .stopped, .error:
            return false
        }
    }
    
    /// Whether status represents an error state
    var isError: Bool {
        switch self {
        case .error:
            return true
        default:
            return false
        }
    }
    
    /// Whether status allows starting recognition
    var canStart: Bool {
        switch self {
        case .idle, .stopped, .error:
            return true
        case .starting, .listening, .processing:
            return false
        }
    }
    
    /// Whether status allows stopping recognition
    var canStop: Bool {
        switch self {
        case .starting, .listening, .processing:
            return true
        case .idle, .stopped, .error:
            return false
        }
    }
}

// MARK: - Status Transitions

extension SpeechRecognitionStatus {
    
    /// Check if transition to new status is valid
    func canTransition(to newStatus: SpeechRecognitionStatus) -> Bool {
        switch (self, newStatus) {
        // From idle
        case (.idle, .starting), (.idle, .error):
            return true
            
        // From starting
        case (.starting, .listening), (.starting, .error), (.starting, .stopped):
            return true
            
        // From listening
        case (.listening, .processing), (.listening, .stopped), (.listening, .error):
            return true
            
        // From processing
        case (.processing, .listening), (.processing, .stopped), (.processing, .error):
            return true
            
        // From stopped
        case (.stopped, .starting), (.stopped, .idle), (.stopped, .error):
            return true
            
        // From error
        case (.error, .starting), (.error, .idle), (.error, .stopped):
            return true
            
        default:
            return false
        }
    }
    
    /// Get next expected status (for validation)
    var expectedNextStatuses: [SpeechRecognitionStatus] {
        switch self {
        case .idle:
            return [.starting]
        case .starting:
            return [.listening, .error, .stopped]
        case .listening:
            return [.processing, .stopped, .error]
        case .processing:
            return [.listening, .stopped, .error]
        case .stopped:
            return [.starting, .idle]
        case .error:
            return [.starting, .idle, .stopped]
        }
    }
}

// MARK: - Factory Methods

extension SpeechRecognitionStatus {
    
    /// Create status from string (for API compatibility)
    static func fromString(_ string: String) -> SpeechRecognitionStatus {
        switch string.lowercased() {
        case "idle": return .idle
        case "starting": return .starting
        case "listening": return .listening
        case "processing": return .processing
        case "stopped": return .stopped
        case let str where str.hasPrefix("error"):
            let message = str.replacingOccurrences(of: "error:", with: "").trimmingCharacters(in: .whitespaces)
            return .error(message.isEmpty ? "Unknown error" : message)
        default: return .error("Unknown status: \(string)")
        }
    }
    
    /// Create error status with message
    static func error(_ message: String) -> SpeechRecognitionStatus {
        return .error(message)
    }
}

// MARK: - Equatable

extension SpeechRecognitionStatus: Equatable {
    static func == (lhs: SpeechRecognitionStatus, rhs: SpeechRecognitionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.starting, .starting), (.listening, .listening),
             (.processing, .processing), (.stopped, .stopped):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
