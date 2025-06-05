// ios/Runner/Speech/SentenceDetection/PurePatternSentenceDetector.swift
// Clean sentence detection based on punctuation

import Foundation

/// Simple sentence detector that finalizes sentences when punctuation is detected
class PurePatternSentenceDetector {
    
    // MARK: - Properties
    
    weak var delegate: SentenceDetectorDelegate?
    
    // State tracking
    private var currentTranscript: String = ""
    private var lastFinalizedText: String = ""
    private var lastFinalizedTimestamp: Date = Date.distantPast
    
    // MARK: - Configuration
    
    struct Config {
        let minimumSentenceLength: Int
        let duplicateSuppressionWindow: TimeInterval
        
        // Hermes optimized config
        static let hermes = Config(
            minimumSentenceLength: 8,  // Allow shorter sentences for better flow
            duplicateSuppressionWindow: 1.5
        )
    }
    
    private let config: Config
    
    // MARK: - Initialization
    
    init(config: Config = .hermes, delegate: SentenceDetectorDelegate? = nil) {
        self.config = config
        self.delegate = delegate
        
        print("✅ [PurePatternDetector] Initialized - Simple punctuation detection")
    }
    
    // MARK: - Public Interface
    
    /// Process transcript and finalize complete sentences
    func processTranscript(_ transcript: String, isFinal: Bool = false) {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanTranscript.isEmpty else { return }
        
        // Skip if no meaningful change
        if cleanTranscript == currentTranscript {
            return
        }
        
        currentTranscript = cleanTranscript
        
        // Always send partial updates for UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sentenceDetector(self, didDetectPartial: cleanTranscript)
        }
        
        // Extract and finalize complete sentences
        _extractAndFinalizeCompleteSentences(from: cleanTranscript)
    }
    
    /// Force finalization of current content
    func forceFinalize(reason: String = "force") {
        if !currentTranscript.isEmpty && currentTranscript.count >= config.minimumSentenceLength {
            _finalizeComplete(currentTranscript, reason: reason)
            currentTranscript = ""
        }
    }
    
    /// Reset state
    func reset() {
        currentTranscript = ""
        // Keep lastFinalizedText for duplicate detection
    }
    
    // MARK: - Core Logic
    
    /// Find complete sentences and finalize them
    private func _extractAndFinalizeCompleteSentences(from text: String) {
        let sentenceEnders: Set<Character> = [".", "?", "!"]
        var currentSentence = ""
        var completeSentences: [String] = []
        
        // Scan character by character
        for char in text {
            currentSentence.append(char)
            
            // If we hit punctuation, we have a complete sentence
            if sentenceEnders.contains(char) {
                let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespaces)
                
                // Only finalize if it meets minimum length and isn't an abbreviation
                if trimmedSentence.count >= config.minimumSentenceLength &&
                   !_isLikelyAbbreviation(trimmedSentence) {
                    completeSentences.append(trimmedSentence)
                    print("🎯 [PurePattern] Found complete sentence: '\(String(trimmedSentence.prefix(50)))...'")
                }
                
                currentSentence = "" // Reset for next sentence
            }
        }
        
        // Finalize all complete sentences
        for sentence in completeSentences {
            _finalizeComplete(sentence, reason: "punctuation-detected")
        }
        
        // Keep any remaining incomplete text
        let remainingText = currentSentence.trimmingCharacters(in: .whitespaces)
        currentTranscript = remainingText
        
        if !remainingText.isEmpty {
            print("📝 [PurePattern] Remaining incomplete: '\(String(remainingText.prefix(30)))...'")
        }
    }
    
    /// Check if sentence ending is likely an abbreviation
    private func _isLikelyAbbreviation(_ text: String) -> Bool {
        let commonAbbreviations = [
            "Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.",
            "Inc.", "Corp.", "Ltd.", "Co.", "LLC.", "etc.", "vs.", "e.g.", "i.e.",
            "Ph.D.", "M.D.", "B.A.", "M.A.", "M.S.", "U.S.", "U.K.", "N.Y.",
            "4%." // Handle percentages like "4%."
        ]
        
        // Check if the text ends with any common abbreviation
        for abbrev in commonAbbreviations {
            if text.hasSuffix(abbrev) {
                return true
            }
        }
        
        // Check for percentage patterns like "69.23%."
        let percentagePattern = #"\d+\.?\d*%\.$"#
        if _matchesPattern(text, pattern: percentagePattern) {
            return true
        }
        
        return false
    }
    
    /// Finalize a complete sentence
    private func _finalizeComplete(_ text: String, reason: String) {
        // Prevent duplicates
        let now = Date()
        let timeSinceLastFinalization = now.timeIntervalSince(lastFinalizedTimestamp)
        
        if text == lastFinalizedText && timeSinceLastFinalization < config.duplicateSuppressionWindow {
            print("🔄 [PurePattern] Skipping duplicate: '\(String(text.prefix(30)))...'")
            return
        }
        
        print("✅ [PurePattern] FINALIZING SENTENCE: '\(String(text.prefix(60)))...' (reason: \(reason))")
        
        // Update tracking
        lastFinalizedText = text
        lastFinalizedTimestamp = now
        
        // Send to delegate on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sentenceDetector(self, didFinalizeSentence: text, reason: reason)
        }
    }
    
    /// Helper for regex matching
    private func _matchesPattern(_ text: String, pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            print("❌ [PurePattern] Regex error: \(error)")
            return false
        }
    }
    
    // MARK: - Debug Support
    
    /// Get current state for debugging
    var debugInfo: [String: Any] {
        return [
            "currentTranscript": currentTranscript,
            "lastFinalizedText": lastFinalizedText,
            "config": [
                "minimumSentenceLength": config.minimumSentenceLength,
                "duplicateSuppressionWindow": config.duplicateSuppressionWindow
            ]
        ]
    }
    
    /// Analyze text for debugging
    func analyzeText(_ text: String) -> [String: Any] {
        let sentenceEnders: Set<Character> = [".", "?", "!"]
        let hasPunctuation = text.contains { sentenceEnders.contains($0) }
        
        return [
            "text": text,
            "length": text.count,
            "hasPunctuation": hasPunctuation,
            "meetsMinimumLength": text.count >= config.minimumSentenceLength,
            "isLikelyAbbreviation": _isLikelyAbbreviation(text),
            "wouldFinalize": hasPunctuation &&
                            text.count >= config.minimumSentenceLength &&
                            !_isLikelyAbbreviation(text)
        ]
    }
}
