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
        
        // 🆕 OPTIMIZATION: Check multiple pattern types with priority
        
        // Priority 1: Strong punctuation patterns (highest confidence)
        if detectStrongPunctuationPattern(in: cleanText) {
            return true
        }
        
        // Priority 2: Question/exclamation endings
        if detectQuestionExclamationEnd(in: cleanText) {
            return true
        }
        
        // Priority 3: Natural period endings
        if detectNaturalPeriodEnd(in: cleanText) {
            return true
        }
        
        // Priority 4: Length-based splitting for very long sentences
        if config.enableLengthBasedSplitting && detectLengthBasedBreak(in: cleanText) {
            return true
        }
        
        // Priority 5: Comma-based splitting with conjunctions
        if config.enableCommaBasedSplitting && detectCommaBasedBreak(in: cleanText) {
            return true
        }
        
        return false
    }
    
    /// Get reason for detection (for debugging)
    func detectionReason(for text: String) -> String? {
        guard hasNaturalBreak(in: text) else {
            return nil
        }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if detectStrongPunctuationPattern(in: cleanText) {
            return "strong-punctuation"
        } else if detectQuestionExclamationEnd(in: cleanText) {
            return "question-exclamation"
        } else if detectNaturalPeriodEnd(in: cleanText) {
            return "natural-period"
        } else if config.enableLengthBasedSplitting && detectLengthBasedBreak(in: cleanText) {
            return "length-based"
        } else if config.enableCommaBasedSplitting && detectCommaBasedBreak(in: cleanText) {
            return "comma-based"
        }
        
        return "unknown"
    }
    
    // MARK: - Enhanced Pattern Detection Methods
    
    /// 🆕 OPTIMIZATION: Strong punctuation patterns with high confidence
    /// Detects clear sentence boundaries like ". However," or "! But then"
    private func detectStrongPunctuationPattern(in text: String) -> Bool {
        // Pattern for punctuation followed by space and capital letter, then a word
        let strongPatterns = [
            #"[.!?]\s+[A-Z][a-z]+\s+"#,           // ". However " or "! But "
            #"[.!?]\s+[A-Z][a-z]*[,:]"#,          // ". So," or "! Yes:"
            #"[.!?]\s+[A-Z][a-z]*ly\s+"#,         // ". Actually " or "! Really "
            #"[.!?]\s+(And|But|So|However|Therefore|Meanwhile|Furthermore|Moreover|Nevertheless|Additionally)\s+"# // Strong transition words
        ]
        
        return strongPatterns.contains { pattern in
            containsRegexPattern(text, pattern: pattern)
        }
    }
    
    /// 🆕 OPTIMIZATION: Enhanced question/exclamation detection
    private func detectQuestionExclamationEnd(in text: String) -> Bool {
        // Require reasonable length for questions/exclamations
        guard text.count >= 15 else {
            return false
        }
        
        // Check for question marks or exclamation points
        if text.hasSuffix("?") || text.hasSuffix("!") {
            return true
        }
        
        // 🆕 Check for questions/exclamations followed by space and new content
        let questionExclamationPatterns = [
            #"[?!]\s+[A-Z]"#,                     // "? How" or "! That"
            #"[?!]\s+(And|But|So|Now|Then)\s+"#   // "? And then" or "! But wait"
        ]
        
        return questionExclamationPatterns.contains { pattern in
            containsRegexPattern(text, pattern: pattern)
        }
    }
    
    /// Enhanced natural period detection
    private func detectNaturalPeriodEnd(in text: String) -> Bool {
        guard text.hasSuffix(".") && text.count >= 15 else {
            return false
        }
        
        // Check if preceded by a lowercase letter (not an abbreviation)
        let beforePeriod = String(String(text.dropLast()).suffix(3))
        let hasLowercaseBefore = beforePeriod.last?.isLowercase == true
        
        // 🆕 OPTIMIZATION: More sophisticated abbreviation detection
        if hasLowercaseBefore && !isLikelyAbbreviation(text) {
            return true
        }
        
        return false
    }
    
    /// 🆕 OPTIMIZATION: Length-based sentence breaking
    private func detectLengthBasedBreak(in text: String) -> Bool {
        // Only apply if text is very long
        guard text.count > 100 else {
            return false
        }
        
        // Look for good break points in long sentences
        return hasGoodLengthBasedBreakPoint(in: text)
    }
    
    /// 🆕 OPTIMIZATION: Comma-based sentence breaking with conjunctions
    private func detectCommaBasedBreak(in text: String) -> Bool {
        // Only apply to reasonably long sentences
        guard text.count >= 30 else {  // Lowered from 40 to catch more cases
            return false
        }
        
        // Look for comma followed by coordinating conjunctions or transition words
        let commaPatterns = [
            #",\s+(and|but|or|so|yet)\s+[a-zA-Z]"#,                    // ", and we", ", but it"
            #",\s+(because|while|when|if|although|since|unless)\s+"#,   // ", because they"
            #",\s+(however|therefore|meanwhile|furthermore|moreover|additionally|consequently)\s+"#, // ", however we"
            #",\s+(then|now|next|finally|lastly)\s+"#,                 // ", then I"
            #",\s+(authentication|hosting|databases)\s+(and|or)\s+"#   // Firebase-specific patterns
        ]
        
        return commaPatterns.contains { pattern in
            containsRegexPattern(text, pattern: pattern)
        }
    }
    
    // MARK: - Enhanced Helper Methods
    
    /// 🆕 OPTIMIZATION: Detect good break points for length-based splitting
    private func hasGoodLengthBasedBreakPoint(in text: String) -> Bool {
        // Look for natural break points in the latter half of the text
        let halfwayPoint = text.count / 2
        let secondHalf = String(text.suffix(text.count - halfwayPoint))
        
        // Check for transition words or phrases that indicate good break points
        let breakPointPatterns = [
            #"\s+(And|But|So|However|Therefore|Meanwhile|Furthermore|Moreover|Then|Now|Next|Finally|Additionally)\s+"#,
            #"\s+(After that|Before that|In addition|On the other hand|For example|In fact|As a result)\s+"#,
            #"[.!?]\s+[A-Z]"# // Any sentence boundary in the second half
        ]
        
        return breakPointPatterns.contains { pattern in
            containsRegexPattern(secondHalf, pattern: pattern)
        }
    }
    
    /// 🆕 OPTIMIZATION: More sophisticated abbreviation detection
    private func isLikelyAbbreviation(_ text: String) -> Bool {
        // Common abbreviations that shouldn't trigger sentence breaks
        let commonAbbreviations = [
            "Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.",
            "Inc.", "Corp.", "Ltd.", "Co.", "LLC.", "etc.", "vs.", "e.g.", "i.e.",
            "Ph.D.", "M.D.", "B.A.", "M.A.", "M.S.", "Ph.D.",
            "U.S.", "U.K.", "U.N.", "E.U.", "N.Y.", "L.A.",
            "Jan.", "Feb.", "Mar.", "Apr.", "Jun.", "Jul.", "Aug.", "Sep.", "Oct.", "Nov.", "Dec."
        ]
        
        // Check the last 10 characters for abbreviations
        let suffix = String(text.suffix(min(10, text.count)))
        
        return commonAbbreviations.contains { abbrev in
            suffix.localizedCaseInsensitiveContains(abbrev)
        }
    }
    
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
    
    /// 🆕 OPTIMIZATION: Advanced context analysis for better accuracy
    func analyzeContext(in text: String) -> [String: Any] {
        return [
            "hasStrongPunctuation": detectStrongPunctuationPattern(in: text),
            "hasQuestionExclamation": detectQuestionExclamationEnd(in: text),
            "hasNaturalPeriod": detectNaturalPeriodEnd(in: text),
            "hasLengthBasedBreak": config.enableLengthBasedSplitting && detectLengthBasedBreak(in: text),
            "hasCommaBasedBreak": config.enableCommaBasedSplitting && detectCommaBasedBreak(in: text),
            "isLikelyAbbreviation": isLikelyAbbreviation(text),
            "hasGoodBreakPoint": hasGoodLengthBasedBreakPoint(in: text),
            "textLength": text.count
        ]
    }
    
    /// Check if text is likely an abbreviation context
    /// Used to avoid false positives like "Dr. Smith"
    private func isAbbreviationContext(before text: String, position: Int) -> Bool {
        // More sophisticated abbreviation detection for Phase 2
        let beforeText = String(String(text.prefix(position)).suffix(15))
        
        // Check for title patterns
        let titlePatterns = [
            #"(Dr|Mr|Mrs|Ms|Prof)\.\s*$"#,
            #"(Inc|Corp|Ltd|Co)\.\s*$"#,
            #"(Ph\.D|M\.D|B\.A|M\.A|M\.S)\.\s*$"#
        ]
        
        return titlePatterns.contains { pattern in
            containsRegexPattern(beforeText, pattern: pattern)
        }
    }
    
    /// 🆕 OPTIMIZATION: Detect language-specific patterns
    private func detectLanguageSpecificPatterns(in text: String, locale: String) -> Bool {
        switch locale.prefix(2) {
        case "es": // Spanish
            return containsRegexPattern(text, pattern: #"[¿¡][^¿¡]*[?!]"#)
        case "fr": // French
            return containsRegexPattern(text, pattern: #"\s*[«»]\s*"#)
        case "de": // German
            return containsRegexPattern(text, pattern: #"\s+(und|aber|oder|denn|sondern)\s+"#)
        default:
            return false
        }
    }
}

// MARK: - Debug Support

extension SentencePatternMatcher {
    
    /// Get detailed analysis for debugging
    func analyzeText(_ text: String) -> [String: Any] {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var analysis: [String: Any] = [
            "text": cleanText,
            "length": cleanText.count,
            "meetsMinimumLength": cleanText.count >= config.minimumLength,
            "hasNaturalBreak": hasNaturalBreak(in: text),
            "detectionReason": detectionReason(for: text) ?? "none"
        ]
        
        // Add detailed pattern analysis
        analysis["patterns"] = [
            "strongPunctuation": detectStrongPunctuationPattern(in: cleanText),
            "questionExclamationEnd": detectQuestionExclamationEnd(in: cleanText),
            "naturalPeriodEnd": detectNaturalPeriodEnd(in: cleanText),
            "lengthBasedBreak": config.enableLengthBasedSplitting && detectLengthBasedBreak(in: cleanText),
            "commaBasedBreak": config.enableCommaBasedSplitting && detectCommaBasedBreak(in: cleanText)
        ]
        
        // Add context analysis
        analysis["context"] = analyzeContext(in: cleanText)
        
        // Add configuration info
        analysis["config"] = [
            "minimumLength": config.minimumLength,
            "maximumLength": config.maximumLength,
            "punctuationDetectionEnabled": config.enablePunctuationDetection,
            "lengthBasedSplittingEnabled": config.enableLengthBasedSplitting,
            "commaBasedSplittingEnabled": config.enableCommaBasedSplitting
        ]
        
        return analysis
    }
}
