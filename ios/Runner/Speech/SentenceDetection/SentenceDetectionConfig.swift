// ios/Runner/Speech/SentenceDetection/SentenceDetectionConfig.swift

import Foundation

/// Configuration for sentence boundary detection behavior
/// Pure data model with no business logic
struct SentenceDetectionConfig {
    
    // MARK: - Timer Configuration
    
    /// Time to wait for transcript stability before finalizing (seconds)
    let stabilityTimeout: TimeInterval
    
    /// Maximum time before forced finalization (seconds)
    let maxSegmentDuration: TimeInterval
    
    // MARK: - Content Configuration
    
    /// Minimum characters before considering finalization
    let minimumLength: Int
    
    /// Maximum characters before forced finalization (0 = no limit)
    let maximumLength: Int
    
    // MARK: - Pattern Detection Configuration
    
    /// Enable punctuation-based detection
    let enablePunctuationDetection: Bool
    
    /// Enable natural pause detection (future)
    let enablePauseDetection: Bool
    
    // MARK: - Initialization
    
    init(
        stabilityTimeout: TimeInterval = 1.5,
        maxSegmentDuration: TimeInterval = 8.0,
        minimumLength: Int = 10,
        maximumLength: Int = 0,
        enablePunctuationDetection: Bool = true,
        enablePauseDetection: Bool = false
    ) {
        self.stabilityTimeout = stabilityTimeout
        self.maxSegmentDuration = maxSegmentDuration
        self.minimumLength = minimumLength
        self.maximumLength = maximumLength
        self.enablePunctuationDetection = enablePunctuationDetection
        self.enablePauseDetection = enablePauseDetection
    }
}

// MARK: - Factory Methods

extension SentenceDetectionConfig {
    
    /// Default configuration for general use
    static let `default` = SentenceDetectionConfig()
    
    /// Configuration optimized for Hermes real-time translation
    static let hermes = SentenceDetectionConfig(
        stabilityTimeout: 1.5,        // Quick response for live translation
        maxSegmentDuration: 6.0,      // Shorter segments for frequent updates
        minimumLength: 8,             // Allow shorter segments for better flow
        maximumLength: 200,           // Prevent extremely long segments
        enablePunctuationDetection: true,
        enablePauseDetection: false
    )
    
    /// Conservative configuration for longer, complete sentences
    static let conservative = SentenceDetectionConfig(
        stabilityTimeout: 2.5,
        maxSegmentDuration: 12.0,
        minimumLength: 15,
        maximumLength: 0,             // No maximum limit
        enablePunctuationDetection: true,
        enablePauseDetection: false
    )
    
    /// Aggressive configuration for rapid-fire speech
    static let aggressive = SentenceDetectionConfig(
        stabilityTimeout: 1.0,
        maxSegmentDuration: 4.0,
        minimumLength: 5,
        maximumLength: 150,
        enablePunctuationDetection: true,
        enablePauseDetection: false
    )
}

// MARK: - Validation

extension SentenceDetectionConfig {
    
    /// Validate configuration values
    var isValid: Bool {
        return stabilityTimeout > 0 &&
               maxSegmentDuration > stabilityTimeout &&
               minimumLength >= 0 &&
               maximumLength >= 0 &&
               (maximumLength == 0 || maximumLength > minimumLength)
    }
    
    /// Validated copy with fallback to default values
    func validated() -> SentenceDetectionConfig {
        guard isValid else {
            print("⚠️ [Config] Invalid configuration, using default")
            return .default
        }
        return self
    }
}

// MARK: - Serialization Support

extension SentenceDetectionConfig {
    
    /// Convert to dictionary for Flutter communication
    func toDictionary() -> [String: Any] {
        return [
            "stabilityTimeout": stabilityTimeout,
            "maxSegmentDuration": maxSegmentDuration,
            "minimumLength": minimumLength,
            "maximumLength": maximumLength,
            "enablePunctuationDetection": enablePunctuationDetection,
            "enablePauseDetection": enablePauseDetection
        ]
    }
    
    /// Create from dictionary (from Flutter)
    static func fromDictionary(_ dict: [String: Any]) -> SentenceDetectionConfig {
        return SentenceDetectionConfig(
            stabilityTimeout: dict["stabilityTimeout"] as? TimeInterval ?? 1.5,
            maxSegmentDuration: dict["maxSegmentDuration"] as? TimeInterval ?? 8.0,
            minimumLength: dict["minimumLength"] as? Int ?? 10,
            maximumLength: dict["maximumLength"] as? Int ?? 0,
            enablePunctuationDetection: dict["enablePunctuationDetection"] as? Bool ?? true,
            enablePauseDetection: dict["enablePauseDetection"] as? Bool ?? false
        ).validated()
    }
}

// MARK: - Debug Support

extension SentenceDetectionConfig {
    
    /// Debug description for logging
    var debugDescription: String {
        return """
        SentenceDetectionConfig {
          stabilityTimeout: \(stabilityTimeout)s
          maxSegmentDuration: \(maxSegmentDuration)s
          minimumLength: \(minimumLength)
          maximumLength: \(maximumLength == 0 ? "unlimited" : "\(maximumLength)")
          punctuationDetection: \(enablePunctuationDetection)
          pauseDetection: \(enablePauseDetection)
        }
        """
    }
}//
//  SentenceDetectionConfig.swift
//  Runner
//
//  Created by Jerson on 6/4/25.
//

