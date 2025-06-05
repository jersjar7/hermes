// ios/Runner/Speech/SentenceDetection/PurePatternSentenceDetector.swift
// Clean sentence detection based on punctuation - inherits minimally from SentenceDetector

import Foundation

/// Simple sentence detector that finalizes sentences when punctuation is detected
class PurePatternSentenceDetector: SentenceDetector {
    
    // MARK: - Additional Properties
    
    // State tracking (in addition to base class)
    private var fullTranscriptSoFar: String = ""
    private var lastProcessedIndex: Int = 0
    private var currentTranscript: String = ""
    private var lastFinalizedText: String = ""
    private var lastFinalizedTimestamp: Date = Date.distantPast
    
    // MARK: - Configuration
    
    struct Config {
        let minimumSentenceLength: Int
        let duplicateSuppressionWindow: TimeInterval
        
        // Hermes optimized config
        static let hermes = Config(
            minimumSentenceLength: 1,  // Allow shorter sentences for better flow
            duplicateSuppressionWindow: 0.5
        )
    }
    
    private let config: Config
    
    // MARK: - Initialization
    
    init(config: Config = .hermes, delegate: SentenceDetectorDelegate? = nil) {
        self.config = config
        
        // Call superclass with minimal config to avoid conflicts
        let baseConfig = SentenceDetectionConfig(
            stabilityTimeout: 999,  // Unused - we override the logic
            maxSegmentDuration: 999,  // Unused - we override the logic
            minimumLength: config.minimumSentenceLength,
            maximumLength: 0,
            enablePunctuationDetection: true,
            enablePauseDetection: false,
            enableLengthBasedSplitting: false,
            enableCommaBasedSplitting: false,
            duplicateSuppressionWindow: config.duplicateSuppressionWindow
        )
        
        super.init(config: baseConfig, delegate: delegate)
        
        print("✅ [PurePatternDetector] Initialized - Simple punctuation detection")
    }
    
    // MARK: - Public Interface (Override base methods)
    
    /// Process transcript and finalize complete sentences (main entry point)
    func processTranscript(_ transcript: String, isFinal: Bool = false) {
        // Use our custom logic instead of base class
        _processTranscriptCustom(transcript, isFinal: isFinal)
    }
    
    /// Override base class method to use our custom logic
    override func processPartialTranscript(_ transcript: String, isFinal: Bool = false) {
        _processTranscriptCustom(transcript, isFinal: isFinal)
    }
    
    /// Our custom processing logic
    private func _processTranscriptCustom(_ transcript: String, isFinal: Bool = false) {
            let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTranscript.isEmpty else {
                return
            }

            // If the transcript hasn't grown, nothing new to do:
            if cleanTranscript == fullTranscriptSoFar {
                return
            }

            // Send partial update to Flutter/UI:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.sentenceDetector(self, didDetectPartial: cleanTranscript)
            }

            // Determine the newly appended substring:
            let previousLength = fullTranscriptSoFar.count
            fullTranscriptSoFar = cleanTranscript
            let newRangeStart = fullTranscriptSoFar.index(fullTranscriptSoFar.startIndex, offsetBy: previousLength)
            let newRange = newRangeStart..<fullTranscriptSoFar.endIndex
            let newlyAppended = String(fullTranscriptSoFar[newRange])

            // Scan only the newly appended characters (plus possibly a bit of overlap)
            // to see if any new punctuation ended up past the lastProcessedIndex:
            extractSentencesFromNewText(fullTranscriptSoFar, fromIndex: lastProcessedIndex)

            // Done.
        }
    
    /// New helper: scans from lastProcessedIndex to end of fullTranscriptSoFar
    private func extractSentencesFromNewText(_ fullText: String, fromIndex startIdx: Int) {
        // Convert string to char array for indexing:
        let characters = Array(fullText)
        let n = characters.count

        // We’ll build one “currentCandidate” from startIdx → each punctuation,
        // but need to know if we already finalized any chunk beyond that.
        var i = startIdx
        var collector = ""

        // If startIdx > 0, we should pick up where the previous round left off:
        // i.e. collector = any “remainder” from fullText[ lastProcessedIndex ..< end ]
        // But since we finalize exactly at punctuation, the remainder (un-finalized) is:
        if startIdx < n {
            // Grab leftover after the last processed index:
            let remainderSlice = fullText[ fullText.index(fullText.startIndex, offsetBy: startIdx) ..< fullText.endIndex ]
            collector = String(remainderSlice)
        }

        // Now scan from the last processed position up to the end:
        while i < n {
            let char = characters[i]
            collector.append(char)

            if [".", "?", "!"].contains(char) {
                // We have a candidate sentence ending: trim whitespace:
                let trimmed = collector.trimmingCharacters(in: .whitespacesAndNewlines)

                // Is it long enough?
                if trimmed.count >= config.minimumSentenceLength && !_isLikelyAbbreviation(trimmed) {
                    // Prevent duplicates:
                    let now = Date()
                    let dt = now.timeIntervalSince(lastFinalizedTimestamp)
                    if trimmed != lastFinalizedText || dt > config.duplicateSuppressionWindow {
                        // Finalize:
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.delegate?.sentenceDetector(self, didFinalizeSentence: trimmed, reason: "punctuation-detected")
                        }
                        lastFinalizedText = trimmed
                        lastFinalizedTimestamp = now
                    }
                }
                // Reset collector *after* you finalize so we start fresh:
                collector = ""
                // Move the “lastProcessedIndex” to the very next character:
                lastProcessedIndex = i + 1
            }

            i += 1
        }

        // After scanning, `collector` is the new “incomplete” chunk; but we don’t need
        // to explicitly store it here because next time we’ll just start scanning at lastProcessedIndex again.
    }
    
    /// Override forceFinalize to handle “flush remaining”:
        override func forceFinalize(reason: String = "force") {
            // If there’s any leftover text after last processed index, finalize that as well:
            let remainderStart = fullTranscriptSoFar.index(fullTranscriptSoFar.startIndex, offsetBy: lastProcessedIndex)
            let remainder = String(fullTranscriptSoFar[ remainderStart..<fullTranscriptSoFar.endIndex ]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty && remainder.count >= config.minimumSentenceLength {
                let now = Date()
                if remainder != lastFinalizedText || now.timeIntervalSince(lastFinalizedTimestamp) > config.duplicateSuppressionWindow {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.delegate?.sentenceDetector(self, didFinalizeSentence: remainder, reason: reason)
                    }
                    lastFinalizedText = remainder
                    lastFinalizedTimestamp = now
                }
            }
        }

        /// Override reset to clear state:
        override func reset() {
            fullTranscriptSoFar = ""
            lastProcessedIndex = 0
            lastFinalizedText = ""
            lastFinalizedTimestamp = .distantPast
        }

        /// Override stop to do a final flush:
        override func stop() {
            forceFinalize(reason: "cleanup")
            super.stop()
        }
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
    
    /// Enhanced abbreviation detection to prevent false sentence breaks
    /// Handles common abbreviations, dates, numbers, and decimal patterns
    private func _isLikelyAbbreviation(_ text: String) -> Bool {
        let commonAbbreviations = [
            // Titles and honorifics
            "Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.", "Drs.",
            
            // Business and legal
            "Inc.", "Corp.", "Ltd.", "Co.", "LLC.", "L.L.C.", "P.C.", "L.P.", "LP.",
            
            // Academic degrees
            "Ph.D.", "M.D.", "B.A.", "M.A.", "M.S.", "B.S.", "M.B.A.", "J.D.", "LL.M.",
            "D.D.S.", "Pharm.D.", "Ed.D.", "Psy.D.",
            
            // Common abbreviations
            "etc.", "vs.", "e.g.", "i.e.", "cf.", "viz.", "et al.", "ibid.",
            
            // Geographic and political
            "U.S.", "U.K.", "U.N.", "E.U.", "N.Y.", "L.A.", "D.C.", "N.J.", "Ca.",
            "N.H.", "R.I.", "Mass.", "Conn.", "Del.", "Md.", "Va.", "N.C.", "S.C.",
            "Ga.", "Fla.", "Ala.", "Miss.", "Tenn.", "Ky.", "Ohio", "Ind.", "Ill.",
            "Mich.", "Wis.", "Minn.", "Iowa", "Mo.", "Ark.", "La.", "Okla.", "Tex.",
            "N.M.", "Ariz.", "Colo.", "Utah", "Nev.", "Calif.", "Ore.", "Wash.",
            "Alaska", "Hawaii",
            
            // Months and time
            "Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.", "Jul.", "Aug.",
            "Sep.", "Sept.", "Oct.", "Nov.", "Dec.",
            "Mon.", "Tue.", "Wed.", "Thu.", "Fri.", "Sat.", "Sun.",
            "a.m.", "p.m.", "A.M.", "P.M.",
            
            // Measurements and units
            "in.", "ft.", "yd.", "mi.", "oz.", "lb.", "lbs.", "kg.", "cm.", "mm.",
            "m.", "km.", "mph", "kph", "sq.", "cu.",
            
            // Currency and financial
            "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF",
            
            // Technology and internet
            "www.", "http.", "https.", "ftp.", "IP.", "URL.", "HTML.", "CSS.", "JS.",
            
            // Miscellaneous common abbreviations
            "No.", "nos.", "#.", "Vol.", "Ch.", "Chap.", "pg.", "pp.", "fig.", "Fig.",
            "Ref.", "refs.", "App.", "Sec.", "min.", "max.", "approx.", "est."
        ]
        
        // Check if the text ends with any common abbreviation
        for abbrev in commonAbbreviations {
            if text.hasSuffix(abbrev) {
                return true
            }
        }
        
        // Check for percentage patterns like "69.23%." or "4%."
        let percentagePattern = #"\d+\.?\d*%\.$"#
        if _matchesPattern(text, pattern: percentagePattern) {
            return true
        }
        
        // Check for decimal numbers like "3.14." or "2.71828."
        // This catches mathematical constants, measurements, etc.
        let decimalNumberPattern = #"\b\d+\.\d+\.?$"#
        if _matchesPattern(text, pattern: decimalNumberPattern) {
            return true
        }
        
        // Check for simple numbers with periods like "1." "2." "3."
        // (often used in numbered lists)
        let numberedListPattern = #"\b\d{1,3}\.$"#
        if _matchesPattern(text, pattern: numberedListPattern) {
            return true
        }
        
        // Check for version numbers like "v1.2.3." or "iOS 16.4."
        let versionPattern = #"\b(v|version|iOS|macOS|Android)\s*\d+(\.\d+)*\.$"#
        if _matchesPattern(text, pattern: versionPattern) {
            return true
        }
        
        // Check for currency amounts like "$123.45." or "€99.99."
        let currencyPattern = #"[\$€£¥]\d+\.\d{2}\.$"#
        if _matchesPattern(text, pattern: currencyPattern) {
            return true
        }
        
        // Check for time formats like "3:30." or "12:45."
        let timePattern = #"\b\d{1,2}:\d{2}\.?$"#
        if _matchesPattern(text, pattern: timePattern) {
            return true
        }
        
        // Check for IP addresses like "192.168.1.1."
        let ipPattern = #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.?$"#
        if _matchesPattern(text, pattern: ipPattern) {
            return true
        }
        
        // Check for scientific notation like "6.022e23."
        let scientificNotationPattern = #"\b\d+\.?\d*[eE][+-]?\d+\.?$"#
        if _matchesPattern(text, pattern: scientificNotationPattern) {
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
    
    // MARK: - Debug Support (inside class to avoid extension conflicts)
    
    /// Get current state for debugging
    func getDebugInfo() -> [String: Any] {
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
    func analyzeTextCustom(_ text: String) -> [String: Any] {
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
