// ios/Runner/Speech/SentenceDetection/PurePatternSentenceDetector.swift
// TIMER-FREE sentence detection based purely on content patterns

import Foundation

/// Pure pattern-based sentence detector - NO TIMERS!
/// Relies solely on linguistic patterns to detect complete sentences
class PurePatternSentenceDetector {
    
    // MARK: - Properties
    
    weak var delegate: SentenceDetectorDelegate?
    private let patternMatcher: SentencePatternMatcher
    
    // State tracking (no timers!)
    private var currentTranscript: String = ""
    private var lastFinalizedText: String = ""
    private var lastFinalizedTimestamp: Date = Date.distantPast
    
    // MARK: - Configuration
    
    struct Config {
        let minimumSentenceLength: Int
        let duplicateSuppressionWindow: TimeInterval
        let enableAdvancedPatterns: Bool
        
        // Hermes optimized config - NO TIMEOUTS!
        static let hermes = Config(
            minimumSentenceLength: 12,  // Reasonable minimum for complete thoughts
            duplicateSuppressionWindow: 1.5,  // Only for true duplicates
            enableAdvancedPatterns: true
        )
        
        // Conservative config for formal speech
        static let conservative = Config(
            minimumSentenceLength: 20,
            duplicateSuppressionWindow: 2.0,
            enableAdvancedPatterns: true
        )
    }
    
    private let config: Config
    
    // MARK: - Initialization
    
    init(config: Config = .hermes, delegate: SentenceDetectorDelegate? = nil) {
        self.config = config
        self.delegate = delegate
        
        // Create pattern matcher with content-only detection
        var patternConfig = SentenceDetectionConfig.hermes
        patternConfig = SentenceDetectionConfig(
            stabilityTimeout: 0,  // 🚫 NO TIMER!
            maxSegmentDuration: 0,  // 🚫 NO TIMER!
            minimumLength: config.minimumSentenceLength,
            maximumLength: 0,  // No artificial limit
            enablePunctuationDetection: true,
            enablePauseDetection: false,
            enableLengthBasedSplitting: config.enableAdvancedPatterns,
            enableCommaBasedSplitting: config.enableAdvancedPatterns,
            duplicateSuppressionWindow: config.duplicateSuppressionWindow
        )
        
        self.patternMatcher = SentencePatternMatcher(config: patternConfig)
        
        print("✅ [PurePatternDetector] Initialized - NO TIMERS, content-only detection")
    }
    
    // MARK: - Public Interface
    
    /// Process transcript - relies PURELY on content patterns
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
        
        // Check for COMPLETE SENTENCE using pure pattern detection
        if _isCompleteIdea(cleanTranscript) {
            let reason = _getCompletionReason(cleanTranscript)
            _finalizeComplete(cleanTranscript, reason: reason)
        }
    }
    
    /// Force finalization (only use sparingly, like app shutdown)
    func forceFinalize(reason: String = "force") {
        if !currentTranscript.isEmpty && currentTranscript.count >= config.minimumSentenceLength {
            _finalizeComplete(currentTranscript, reason: reason)
        }
    }
    
    // MARK: - Pure Content Analysis (No Timers!)
    
    /// Determine if content represents a complete idea/sentence
    private func _isCompleteIdea(_ text: String) -> Bool {
        // Must meet minimum length for a complete thought
        guard text.count >= config.minimumSentenceLength else {
            return false
        }
        
        // PRIORITY 1: Clear sentence endings with punctuation
        if _hasDefinitiveSentenceEnding(text) {
            print("📝 [PurePattern] Definitive ending detected: '\(String(text.suffix(20)))'")
            return true
        }
        
        // PRIORITY 2: Complete question or exclamation
        if _hasCompleteQuestionOrExclamation(text) {
            print("❓ [PurePattern] Complete question/exclamation: '\(String(text.suffix(20)))'")
            return true
        }
        
        // PRIORITY 3: Natural transition between complete thoughts
        if config.enableAdvancedPatterns && _hasNaturalThoughtTransition(text) {
            print("🔄 [PurePattern] Thought transition detected")
            return true
        }
        
        // PRIORITY 4: Complete clause with natural pause indicators
        if config.enableAdvancedPatterns && _hasCompleteClauseWithBreak(text) {
            print("✂️ [PurePattern] Complete clause with break")
            return true
        }
        
        return false
    }
    
    /// Detect definitive sentence endings (periods, but not abbreviations)
    private func _hasDefinitiveSentenceEnding(_ text: String) -> Bool {
        // Must end with period
        guard text.hasSuffix(".") else { return false }
        
        // Check if it's a real sentence ending, not an abbreviation
        if _isAbbreviationEnding(text) {
            return false
        }
        
        // Look for pattern: [word]. [Capital letter] or [word].[end]
        let periodPattern = #"[a-z]\.\s*([A-Z]|$)"#
        if _matchesPattern(text, pattern: periodPattern) {
            return true
        }
        
        // For single sentences ending with period
        if !text.contains(". ") && text.count >= config.minimumSentenceLength {
            return true
        }
        
        return false
    }
    
    /// Detect complete questions or exclamations
    private func _hasCompleteQuestionOrExclamation(_ text: String) -> Bool {
        // Simple case: ends with ? or !
        if text.hasSuffix("?") || text.hasSuffix("!") {
            return true
        }
        
        // Complex case: question/exclamation followed by new thought
        let qePattern = #"[?!]\s+[A-Z]"#
        return _matchesPattern(text, pattern: qePattern)
    }
    
    /// Detect natural transitions between complete thoughts
    private func _hasNaturalThoughtTransition(_ text: String) -> Bool {
        // Look for strong transition patterns that indicate sentence boundaries
        let transitionPatterns = [
            #"[.!?]\s+(However|Nevertheless|Therefore|Meanwhile|Furthermore|Moreover|Additionally|Consequently)\s+[a-zA-Z]"#,
            #"[.!?]\s+(And then|But then|So then|After that|Before that)\s+[a-zA-Z]"#,
            #"[.!?]\s+(In fact|For example|On the other hand|As a result)\s+[a-zA-Z]"#
        ]
        
        return transitionPatterns.contains { pattern in
            _matchesPattern(text, pattern: pattern)
        }
    }
    
    /// Detect complete clauses with natural break indicators
    private func _hasCompleteClauseWithBreak(_ text: String) -> Bool {
        // For longer sentences, look for natural breaking points
        guard text.count > 60 else { return false }
        
        // Look for coordinating conjunction patterns that complete thoughts
        let clausePatterns = [
            #",\s+(and|but)\s+[a-zA-Z]+\s+[a-zA-Z]+\s+(is|are|was|were|will|would|can|could|should|might)"#,
            #",\s+(so|therefore)\s+[a-zA-Z]+\s+[a-zA-Z]+"#,
            #",\s+(which|that)\s+[a-zA-Z]+\s+[a-zA-Z]+\s+(is|are|was|were)"#
        ]
        
        return clausePatterns.contains { pattern in
            _matchesPattern(text, pattern: pattern)
        }
    }
    
    /// Check if period ending is likely an abbreviation
    private func _isAbbreviationEnding(_ text: String) -> Bool {
        let commonAbbreviations = [
            "Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.",
            "Inc.", "Corp.", "Ltd.", "Co.", "LLC.", "etc.", "vs.", "e.g.", "i.e.",
            "Ph.D.", "M.D.", "B.A.", "M.A.", "M.S.", "U.S.", "U.K.", "N.Y."
        ]
        
        let suffix = String(text.suffix(15))
        return commonAbbreviations.contains { abbrev in
            suffix.localizedCaseInsensitiveContains(abbrev)
        }
    }
    
    /// Get reason for completion (for debugging)
    private func _getCompletionReason(_ text: String) -> String {
        if _hasDefinitiveSentenceEnding(text) {
            return "definitive-ending"
        } else if _hasCompleteQuestionOrExclamation(text) {
            return "question-exclamation"
        } else if _hasNaturalThoughtTransition(text) {
            return "thought-transition"
        } else if _hasCompleteClauseWithBreak(text) {
            return "complete-clause"
        }
        return "pattern-match"
    }
    
    /// Finalize complete sentence
    private func _finalizeComplete(_ text: String, reason: String) {
        // Prevent duplicates
        let now = Date()
        let timeSinceLastFinalization = now.timeIntervalSince(lastFinalizedTimestamp)
        
        if text == lastFinalizedText && timeSinceLastFinalization < config.duplicateSuppressionWindow {
            print("🔄 [PurePattern] Skipping duplicate: '\(String(text.prefix(30)))...'")
            return
        }
        
        print("✅ [PurePattern] COMPLETE SENTENCE: '\(String(text.prefix(50)))...' (reason: \(reason))")
        
        // Update tracking
        lastFinalizedText = text
        lastFinalizedTimestamp = now
        currentTranscript = ""
        
        // Send to delegate
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
    
    /// Analyze text patterns for debugging
    func analyzeText(_ text: String) -> [String: Any] {
        return [
            "text": text,
            "length": text.count,
            "isCompleteIdea": _isCompleteIdea(text),
            "hasDefinitiveEnding": _hasDefinitiveSentenceEnding(text),
            "hasQuestionExclamation": _hasCompleteQuestionOrExclamation(text),
            "hasThoughtTransition": _hasNaturalThoughtTransition(text),
            "hasCompleteClause": _hasCompleteClauseWithBreak(text),
            "isAbbreviation": _isAbbreviationEnding(text),
            "completionReason": _getCompletionReason(text)
        ]
    }
    
    /// Reset state
    func reset() {
        currentTranscript = ""
        // Keep lastFinalizedText for duplicate detection across resets
    }
}
