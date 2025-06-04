// ios/Runner/Speech/Recognition/SpeechRecognitionConfig.swift

import Foundation

/// Configuration for speech recognition behavior
/// Pure data model with no business logic
struct SpeechRecognitionConfig {
    
    // MARK: - Recognition Settings
    
    /// Language locale for recognition (e.g., "en-US", "es-ES")
    let locale: String
    
    /// Use on-device recognition when available (iOS 13+)
    let onDeviceRecognition: Bool
    
    /// Report partial results during recognition
    let partialResults: Bool
    
    // MARK: - Quality Settings
    
    /// Preferred audio quality level
    let audioQuality: AudioQuality
    
    /// Enable noise suppression if available
    let enableNoiseSupression: Bool
    
    // MARK: - Initialization
    
    init(
        locale: String = "en-US",
        onDeviceRecognition: Bool = true,
        partialResults: Bool = true,
        audioQuality: AudioQuality = .balanced,
        enableNoiseSupression: Bool = true
    ) {
        self.locale = locale
        self.onDeviceRecognition = onDeviceRecognition
        self.partialResults = partialResults
        self.audioQuality = audioQuality
        self.enableNoiseSupression = enableNoiseSupression
    }
}

// MARK: - Audio Quality Options

extension SpeechRecognitionConfig {
    
    enum AudioQuality: String, CaseIterable {
        case low = "low"
        case balanced = "balanced"
        case high = "high"
        
        var sampleRate: Double {
            switch self {
            case .low: return 16000.0
            case .balanced: return 22050.0
            case .high: return 44100.0
            }
        }
        
        var bufferSize: Int {
            switch self {
            case .low: return 512
            case .balanced: return 1024
            case .high: return 2048
            }
        }
    }
}

// MARK: - Factory Methods

extension SpeechRecognitionConfig {
    
    /// Default configuration for general use
    static let `default` = SpeechRecognitionConfig()
    
    /// Configuration optimized for Hermes real-time translation
    static let hermes = SpeechRecognitionConfig(
        locale: "en-US",
        onDeviceRecognition: true,        // Better continuity
        partialResults: true,             // Real-time feedback
        audioQuality: .balanced,          // Good quality without excessive processing
        enableNoiseSupression: true       // Clean audio for better recognition
    )
    
    /// High-quality configuration for professional use
    static let professional = SpeechRecognitionConfig(
        locale: "en-US",
        onDeviceRecognition: true,
        partialResults: true,
        audioQuality: .high,
        enableNoiseSupression: true
    )
    
    /// Low-resource configuration for older devices
    static let lowResource = SpeechRecognitionConfig(
        locale: "en-US",
        onDeviceRecognition: false,       // Fallback to server
        partialResults: true,
        audioQuality: .low,
        enableNoiseSupression: false
    )
}

// MARK: - Validation

extension SpeechRecognitionConfig {
    
    /// Validate configuration values
    var isValid: Bool {
        return !locale.isEmpty &&
               locale.contains("-") &&          // Must be format like "en-US"
               locale.count >= 5
    }
    
    /// Create validated copy with fallback to default values
    func validated() -> SpeechRecognitionConfig {
        guard isValid else {
            print("⚠️ [SpeechConfig] Invalid configuration, using default")
            return .default
        }
        return self
    }
}

// MARK: - Serialization Support

extension SpeechRecognitionConfig {
    
    /// Convert to dictionary for Flutter communication
    func toDictionary() -> [String: Any] {
        return [
            "locale": locale,
            "onDeviceRecognition": onDeviceRecognition,
            "partialResults": partialResults,
            "audioQuality": audioQuality.rawValue,
            "enableNoiseSupression": enableNoiseSupression
        ]
    }
    
    /// Create from dictionary (from Flutter)
    static func fromDictionary(_ dict: [String: Any]) -> SpeechRecognitionConfig {
        let audioQualityString = dict["audioQuality"] as? String ?? "balanced"
        let audioQuality = AudioQuality(rawValue: audioQualityString) ?? .balanced
        
        return SpeechRecognitionConfig(
            locale: dict["locale"] as? String ?? "en-US",
            onDeviceRecognition: dict["onDeviceRecognition"] as? Bool ?? true,
            partialResults: dict["partialResults"] as? Bool ?? true,
            audioQuality: audioQuality,
            enableNoiseSupression: dict["enableNoiseSupression"] as? Bool ?? true
        ).validated()
    }
}

// MARK: - Debug Support

extension SpeechRecognitionConfig {
    
    /// Debug description for logging
    var debugDescription: String {
        return """
        SpeechRecognitionConfig {
          locale: \(locale)
          onDeviceRecognition: \(onDeviceRecognition)
          partialResults: \(partialResults)
          audioQuality: \(audioQuality.rawValue) (\(audioQuality.sampleRate)Hz)
          noiseSupression: \(enableNoiseSupression)
        }
        """
    }
}
