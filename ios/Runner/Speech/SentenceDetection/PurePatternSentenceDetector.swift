// ios/Runner/Speech/SentenceDetection/PurePatternSentenceDetector.swift
// Clean sentence detection based on punctuation - inherits minimally from SentenceDetector

import Foundation

/// Simple sentence detector that finalizes on punctuation,
/// processing only the newly appended text plus any leftover remainder.
class PurePatternSentenceDetector: SentenceDetector {
    
    // MARK: - State Variables
    
    /// The entire transcript Apple has returned so far (with punctuation, when iOS decided to finalize).
    private var fullTranscriptSoFar: String = ""
    
    /// Any "remainder" (incomplete fragment) after the last punctuation
    /// detected in a previous pass. We'll prepend this to new text on each call.
    private var remainder: String = ""
    
    /// The very last sentence we finalized (so we don't emit duplicates).
    private var lastFinalizedText: String = ""
    
    /// Timestamp of when we last finalized a sentence.
    private var lastFinalizedTimestamp: Date = .distantPast
    
    // MARK: - Configuration
    
    struct Config {
        let minimumSentenceLength: Int
        let duplicateSuppressionWindow: TimeInterval
        
        static let hermes = Config(
            minimumSentenceLength: 1,     // split on any punctuation
            duplicateSuppressionWindow: 0.5 // skip duplicates < 0.5s apart
        )
    }
    
    private let config: Config
    
    // MARK: - Initialization
    
    init(config: Config = .hermes, delegate: SentenceDetectorDelegate? = nil) {
        self.config = config
        
        // We still have to call super.init(...) even though we'll override all splitting logic.
        let baseConfig = SentenceDetectionConfig(
            stabilityTimeout: 999,           // unused
            maxSegmentDuration: 999,         // unused
            minimumLength: config.minimumSentenceLength,
            maximumLength: 0,
            enablePunctuationDetection: true,
            enablePauseDetection: false,
            enableLengthBasedSplitting: false,
            enableCommaBasedSplitting: false,
            duplicateSuppressionWindow: config.duplicateSuppressionWindow
        )
        
        super.init(config: baseConfig, delegate: delegate)
        print("✅ [PurePatternDetector] Initialized – punctuation-only splitting")
    }
    
    // MARK: - Public Interface Overrides
    
    /// Called by your `SpeechMethodHandler` on every iOS partial or final callback.
    /// We ignore `isFinal` because punctuation is our sole criterion.
    func processTranscript(_ transcript: String, isFinal: Bool = false) {
        _processTranscriptCustom(transcript)
    }
    
    override func processPartialTranscript(_ transcript: String, isFinal: Bool = false) {
        _processTranscriptCustom(transcript)
    }
    
    /// Force-finalize any leftover remainder (called when you explicitly stop recognition).
    override func forceFinalize(reason: String = "force") {
        // If any remainder is non-empty and meets minimum length, finalize it.
        let text = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && text.count >= config.minimumSentenceLength {
            let now = Date()
            let dt = now.timeIntervalSince(lastFinalizedTimestamp)
            if text != lastFinalizedText || dt > config.duplicateSuppressionWindow {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.sentenceDetector(self, didFinalizeSentence: text, reason: reason)
                }
                lastFinalizedText = text
                lastFinalizedTimestamp = now
            }
        }
    }
    
    override func reset() {
        fullTranscriptSoFar = ""
        remainder = ""
        lastFinalizedText = ""
        lastFinalizedTimestamp = .distantPast
    }
    
    override func stop() {
        forceFinalize(reason: "cleanup")
        super.stop()
    }
    
    // MARK: - Core "Incremental" Logic
    
    private func _processTranscriptCustom(_ transcript: String) {
        // Trim whitespace/newlines
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        // If nothing new has appeared, do nothing
        if clean == fullTranscriptSoFar {
            return
        }
        
        // 1) Notify delegate that we have a "partial" transcript (for UI)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sentenceDetector(self, didDetectPartial: clean)
        }
        
        // 2) Figure out exactly what just got appended
        let oldLength = fullTranscriptSoFar.count
        fullTranscriptSoFar = clean
        let newLength = clean.count
        
        // The "new segment" is whatever Apple sent between oldLength ..< newLength
        let startIndex = fullTranscriptSoFar.index(fullTranscriptSoFar.startIndex, offsetBy: oldLength)
        let newSegment = String(fullTranscriptSoFar[startIndex..<fullTranscriptSoFar.endIndex])
        
        // 3) Combine any leftover "remainder" with the brand-new text
        var collector = remainder + newSegment
        
        // 4) Scan `collector` for punctuation. Every time we see ".", "?", or "!",
        //     that marks the end of one complete sentence. We then finalize it,
        //     reset `collector` to the text after that punctuation, and continue scanning.
        
        var sentencesToEmit: [String] = []
        var temp = ""
        
        for char in collector {
            temp.append(char)
            if [".", "?", "!"].contains(char) {
                let trimmed = temp.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 5) Only emit if it's at least `minimumSentenceLength` long
                //    and does NOT match a known abbreviation / decimal pattern
                if trimmed.count >= config.minimumSentenceLength &&
                   !_isLikelyAbbreviation(trimmed) {
                    sentencesToEmit.append(trimmed)
                }
                temp = ""
            }
        }
        
        // 6) Whatever is left in `temp` (after the last punctuation) becomes the new "remainder"
        remainder = temp.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 7) Finalize each complete sentence in chronological order, applying duplicate suppression
        for sentence in sentencesToEmit {
            let now = Date()
            let dt = now.timeIntervalSince(lastFinalizedTimestamp)
            if sentence != lastFinalizedText || dt > config.duplicateSuppressionWindow {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.sentenceDetector(self, didFinalizeSentence: sentence, reason: "punctuation-detected")
                }
                lastFinalizedText = sentence
                lastFinalizedTimestamp = now
            }
        }
    }
    
    // MARK: - Abbreviation / Decimal Detection
    
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
        
        // 1) If it ends with a common "abbrev.", skip
        for a in commonAbbreviations {
            if text.hasSuffix(a) {
                return true
            }
        }
        
        // 2) Percentage patterns like "69.23%." or "4%."
        let percentPattern = #"\d+\.?\d*%\.$"#
        if _matchesPattern(text, pattern: percentPattern) {
            return true
        }
        
        // 3) Decimal numbers like "3.14." or "2.71828."
        let decimalPattern = #"\b\d+\.\d+\.?$"#
        if _matchesPattern(text, pattern: decimalPattern) {
            return true
        }
        
        // 4) Numbered lists "1.", "2.", "3.", etc.
        let numberedListPattern = #"\b\d{1,3}\.$"#
        if _matchesPattern(text, pattern: numberedListPattern) {
            return true
        }
        
        // 5) Versions like "v1.2.3." or "iOS 16.4."
        let versionPattern = #"\b(v|version|iOS|macOS|Android)\s*\d+(\.\d+)*\.$"#
        if _matchesPattern(text, pattern: versionPattern) {
            return true
        }
        
        // 6) Currency amounts like "$123.45." or "€99.99."
        let currencyPattern = #"[\$€£¥]\d+\.\d{2}\.$"#
        if _matchesPattern(text, pattern: currencyPattern) {
            return true
        }
        
        // 7) Time formats like "3:30." or "12:45."
        let timePattern = #"\b\d{1,2}:\d{2}\.?$"#
        if _matchesPattern(text, pattern: timePattern) {
            return true
        }
        
        // 8) IP addresses like "192.168.1.1."
        let ipPattern = #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.?$"#
        if _matchesPattern(text, pattern: ipPattern) {
            return true
        }
        
        // 9) Scientific notation like "6.022e23."
        let sciPattern = #"\b\d+\.?\d*[eE][+-]?\d+\.?$"#
        if _matchesPattern(text, pattern: sciPattern) {
            return true
        }
        
        return false
    }
    
    /// Simple helper for regex matching
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
    
    // MARK: - Debug Helpers
    
    /// If you want to debug internal state from Flutter,
    /// you can call this and ship it over your "debug" event.
    func getDebugInfo() -> [String: Any] {
        return [
            "remainder": remainder,
            "fullTranscriptSoFar": fullTranscriptSoFar,
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
