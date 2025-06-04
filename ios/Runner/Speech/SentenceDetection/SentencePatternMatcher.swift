// ios/Runner/Speech/SentenceDetection/SentencePatternMatcher.swift

import Foundation

/// Pure pattern detection logic for sentence boundaries
/// Stateless - only analyzes text without maintaining state
class SentencePatternMatcher {
    
    // MARK: - Properties
    
    private let config: SentenceDetectionConfig
    
    // MARK: - Initialization
    
    init(config: SentenceDetectionConfig) {
        self.config = config
    }
    
    // MARK: - Public Interface
    
    /// Check if text contains a natural sentence boundary
    /// Returns true if a boundary is detected and text meets minimum requirements
    func hasNaturalBreak(in text: String) -> Bool {
        guard config.enablePunctuationDetection else {
            return false
        }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must meet minimum length requirement
        guard cleanText.count >= config.minimumLength else {
            return false
        }
        
        // Check for various sentence boundary patterns
        return detectSentenceEndPattern(in: cleanText) ||
               detectQuestionExclamationEnd(in: cleanText) ||
               detectNaturalPeriodEnd(in: cleanText)
    }
    
    /// Get reason for detection (for debugging)
    func detectionReason(for text: String) -> String? {
        guard hasNaturalBreak(in: text) else {
            return nil
        }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if detectSentenceEndPattern(in: cleanText) {
            return "sentence-end-pattern"
        } else if detectQuestionExclamationEnd(in: cleanText) {
            return "question-exclamation-end"
        } else if detectNaturalPeriodEnd(in: cleanText) {
            return "natural-period-end"
        }
        
        return "unknown"
    }
    
    // MARK: - Pattern Detection Methods
    
    /// Pattern 1: Sentence ending punctuation followed by space and capital letter
    /// "Hello world. How are you" -> true
    private func detectSentenceEndPattern(in text: String) -> Bool {
        let pattern = #"[.!?]\s+[A-Z]"#
        return containsRegexPattern(text, pattern: pattern)
    }
    
    /// Pattern 2: Question or exclamation at end with sufficient length
    /// "How are you doing today?" -> true (if long enough)
    private func detectQuestionExclamationEnd(in text: String) -> Bool {
        guard text.count >= 20 else {
            return false
        }
        
        return text.hasSuffix("?") || text.hasSuffix("!")
    }
    
    /// Pattern 3: Period at end with lowercase letter context
    /// "This is a complete sentence." -> true (if preceded by lowercase)
    private func detectNaturalPeriodEnd(in text: String) -> Bool {
        guard text.hasSuffix(".") && text.count >= 15 else {
            return false
        }
        
        // Check if preceded by a lowercase letter (not an abbreviation)
        let beforePeriod = String(text.dropLast()).suffix(3)
        return beforePeriod.last?.isLowercase == true
    }
    
    // MARK: - Helper Methods
    
    /// Check if text contains a regex pattern
    private func containsRegexPattern(_ text: String, pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            print("❌ [PatternMatcher] Regex error for pattern '\(pattern)': \(error)")
            return false
        }
    }
}

// MARK: - Future Pattern Extensions

extension SentencePatternMatcher {
    
    /// Check if text is likely an abbreviation context
    /// Used to avoid false positives like "Dr. Smith"
    /// TODO: Implement for Phase 2
    private func isAbbreviationContext(before text: String, position: Int) -> Bool {
        // Common abbreviations that shouldn't trigger sentence breaks
        let commonAbbreviations = [
            "Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.",
            "Inc.", "Corp.", "Ltd.", "Co.", "etc.", "vs.", "e.g.", "i.e."
        ]
        
        // Simple check for now - more sophisticated logic in Phase 2
        let beforeText = String(text.prefix(position)).suffix(10)
        return commonAbbreviations.contains { abbrev in
            beforeText.localizedCaseInsensitiveContains(abbrev)
        }
    }
    
    /// Detect natural pause indicators in text
    /// TODO: Implement for Phase 2 with audio analysis
    private func hasNaturalPause(in text: String) -> Bool {
        // Placeholder for future pause detection
        // Will integrate with audio analysis
        return false
    }
    
    /// Detect language-specific patterns
    /// TODO: Implement for Phase 2 with multi-language support
    private func detectLanguageSpecificPatterns(in text: String, locale: String) -> Bool {
        // Different languages have different sentence patterns
        // Spanish: ¿ and ¡ patterns
        // French: Different punctuation spacing
        // etc.
        return false
    }
}

// MARK: - Debug Support

extension SentencePatternMatcher {
    
    /// Get detailed analysis for debugging
    func analyzeText(_ text: String) -> [String: Any] {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return [
            "text": cleanText,
            "length": cleanText.count,
            "meetsMinimumLength": cleanText.count >= config.minimumLength,
            "hasNaturalBreak": hasNaturalBreak(in: text),
            "detectionReason": detectionReason(for: text) ?? "none",
            "patterns": [
                "sentenceEndPattern": detectSentenceEndPattern(in: cleanText),
                "questionExclamationEnd": detectQuestionExclamationEnd(in: cleanText),
                "naturalPeriodEnd": detectNaturalPeriodEnd(in: cleanText)
            ],
            "config": [
                "minimumLength": config.minimumLength,
                "punctuationDetectionEnabled": config.enablePunctuationDetection
            ]
        ]
    }
}//
//  SentencePatternMatcher.swift
//  Runner
//
//  Created by Jerson on 6/4/25.
//

