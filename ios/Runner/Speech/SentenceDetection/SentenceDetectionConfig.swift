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
    
    // 🆕 OPTIMIZATION: Enhanced pattern detection settings
    
    /// Enable length-based sentence splitting for very long sentences
    let enableLengthBasedSplitting: Bool
    
    /// Enable comma-based splitting when combined with conjunctions
    let enableCommaBasedSplitting: Bool
    
    /// Minimum time between duplicate finalizations (seconds)
    let duplicateSuppressionWindow: TimeInterval
    
    // MARK: - Initialization
    
    init(
        stabilityTimeout: TimeInterval = 1.5,
        maxSegmentDuration: TimeInterval = 8.0,
        minimumLength: Int = 10,
        maximumLength: Int = 0,
        enablePunctuationDetection: Bool = true,
        enablePauseDetection: Bool = false,
        enableLengthBasedSplitting: Bool = true,
        enableCommaBasedSplitting: Bool = true,
        duplicateSuppressionWindow: TimeInterval = 2.0
    ) {
        self.stabilityTimeout = stabilityTimeout
        self.maxSegmentDuration = maxSegmentDuration
        self.minimumLength = minimumLength
        self.maximumLength = maximumLength
        self.enablePunctuationDetection = enablePunctuationDetection
        self.enablePauseDetection = enablePauseDetection
        self.enableLengthBasedSplitting = enableLengthBasedSplitting
        self.enableCommaBasedSplitting = enableCommaBasedSplitting
        self.duplicateSuppressionWindow = duplicateSuppressionWindow
    }
}

// MARK: - Factory Methods

extension SentenceDetectionConfig {
    
    /// Default configuration for general use
    static let `default` = SentenceDetectionConfig()
    
    /// 🆕 OPTIMIZATION: Enhanced configuration optimized for Hermes real-time translation
    static let hermes = SentenceDetectionConfig(
        stabilityTimeout: 1.2,        // ⚡ Faster response for live translation
        maxSegmentDuration: 4.0,      // 🔄 Shorter segments for frequent updates
        minimumLength: 8,             // ✅ Allow shorter segments for better flow
        maximumLength: 120,           // 📏 Lower limit for better translation chunks
        enablePunctuationDetection: true,
        enablePauseDetection: false,
        enableLengthBasedSplitting: true,    // 🆕 Split very long sentences
        enableCommaBasedSplitting: true,     // 🆕 Split at natural comma breaks
        duplicateSuppressionWindow: 1.5      // 🆕 Prevent rapid duplicates
    )
    
    /// 🆕 OPTIMIZATION: Aggressive configuration for rapid-fire speech and conversations
    static let aggressive = SentenceDetectionConfig(
        stabilityTimeout: 0.8,        // ⚡ Very fast response
        maxSegmentDuration: 3.0,      // 🔄 Very short segments
        minimumLength: 5,             // ✅ Allow very short segments
        maximumLength: 80,            // 📏 Force frequent breaks
        enablePunctuationDetection: true,
        enablePauseDetection: false,
        enableLengthBasedSplitting: true,
        enableCommaBasedSplitting: true,
        duplicateSuppressionWindow: 1.0      // 🆕 Shorter suppression for fast speech
    )
    
    /// Conservative configuration for longer, complete sentences
    static let conservative = SentenceDetectionConfig(
        stabilityTimeout: 2.5,
        maxSegmentDuration: 12.0,
        minimumLength: 15,
        maximumLength: 0,             // No maximum limit
        enablePunctuationDetection: true,
        enablePauseDetection: false,
        enableLengthBasedSplitting: false,   // 🆕 Disable for conservative mode
        enableCommaBasedSplitting: false,    // 🆕 Disable for conservative mode
        duplicateSuppressionWindow: 3.0      // 🆕 Longer suppression window
    )
    
    /// 🆕 OPTIMIZATION: Perfect for presentations and formal speech
    static let presentation = SentenceDetectionConfig(
        stabilityTimeout: 2.0,        // Allow for pauses in formal speech
        maxSegmentDuration: 8.0,      // Reasonable segment length
        minimumLength: 12,            // Ensure meaningful segments
        maximumLength: 200,           // Allow longer formal sentences
        enablePunctuationDetection: true,
        enablePauseDetection: false,
        enableLengthBasedSplitting: true,    // Split very long sentences
        enableCommaBasedSplitting: true,     // Split at natural breaks
        duplicateSuppressionWindow: 2.5      // Account for presentation pauses
    )
    
    /// 🆕 OPTIMIZATION: Optimized for casual conversation and Q&A
    static let conversation = SentenceDetectionConfig(
        stabilityTimeout: 1.0,        // Quick response for back-and-forth
        maxSegmentDuration: 5.0,      // Short segments for conversation flow
        minimumLength: 6,             // Allow short responses like "Yes", "No", "Okay"
        maximumLength: 100,           // Reasonable limit for conversation
        enablePunctuationDetection: true,
        enablePauseDetection: false,
        enableLengthBasedSplitting: true,
        enableCommaBasedSplitting: true,
        duplicateSuppressionWindow: 1.2      // Quick suppression for conversation
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
               (maximumLength == 0 || maximumLength > minimumLength) &&
               duplicateSuppressionWindow >= 0
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
            "enablePauseDetection": enablePauseDetection,
            "enableLengthBasedSplitting": enableLengthBasedSplitting,
            "enableCommaBasedSplitting": enableCommaBasedSplitting,
            "duplicateSuppressionWindow": duplicateSuppressionWindow
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
            enablePauseDetection: dict["enablePauseDetection"] as? Bool ?? false,
            enableLengthBasedSplitting: dict["enableLengthBasedSplitting"] as? Bool ?? true,
            enableCommaBasedSplitting: dict["enableCommaBasedSplitting"] as? Bool ?? true,
            duplicateSuppressionWindow: dict["duplicateSuppressionWindow"] as? TimeInterval ?? 2.0
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
          lengthBasedSplitting: \(enableLengthBasedSplitting)
          commaBasedSplitting: \(enableCommaBasedSplitting)
          duplicateSuppressionWindow: \(duplicateSuppressionWindow)s
        }
        """
    }
    
    /// 🆕 OPTIMIZATION: Get recommended config based on use case
    static func recommended(for useCase: UseCase) -> SentenceDetectionConfig {
        switch useCase {
        case .translation:
            return .hermes
        case .presentation:
            return .presentation
        case .conversation:
            return .conversation
        case .dictation:
            return .conservative
        case .fastSpeech:
            return .aggressive
        }
    }
    
    enum UseCase {
        case translation     // Real-time translation (Hermes)
        case presentation    // Formal presentations
        case conversation    // Casual conversation/Q&A
        case dictation      // Document dictation
        case fastSpeech     // Rapid-fire speech
    }
}
