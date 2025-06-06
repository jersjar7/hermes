// ios/Runner/Speech/SentenceDetection/PurePatternSentenceDetector.swift

import Foundation

/// Simple sentence detector that finalizes on punctuation,
/// processing only the newly appended text plus any leftover remainder.
class PurePatternSentenceDetector: SentenceDetector {
    
    // MARK: - State Variables
    
    /// The last transcript Apple returned (including any punctuation it inserted).
    private var fullTranscriptSoFar: String = ""
    
    /// Any “tail” fragment after the final punctuation in the previous pass.
    /// We prepend this to new text on each call.
    private var remainder: String = ""
    
    /// The very last sentence we emitted, to avoid duplicates.
    private var lastFinalizedText: String = ""
    
    /// When we last emitted a sentence, to enforce a suppression window.
    private var lastFinalizedTimestamp: Date = .distantPast
    
    // MARK: - Configuration
    
    struct Config {
        let minimumSentenceLength: Int
        let duplicateSuppressionWindow: TimeInterval
        
        static let hermes = Config(
            minimumSentenceLength: 1,      // split on any punctuation mark
            duplicateSuppressionWindow: 0.5 // skip duplicates under 0.5s apart
        )
    }
    
    private let config: Config
    
    // MARK: - Initialization
    
    init(config: Config = .hermes, delegate: SentenceDetectorDelegate? = nil) {
        self.config = config
        
        // We still pass a dummy SentenceDetectionConfig up to super, but we ignore most of it.
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
    
    // MARK: - Public Overrides
    
    /// Called by your `SpeechMethodHandler` on _every_ iOS partial or final callback.
    /// We ignore `isFinal` because we rely solely on punctuation marks.
    func processTranscript(_ transcript: String, isFinal: Bool = false) {
        _processTranscriptCustom(transcript)
    }
    
    override func processPartialTranscript(_ transcript: String, isFinal: Bool = false) {
        _processTranscriptCustom(transcript)
    }
    
    /// Force‐finish whatever leftover is still in `remainder`.
    override func forceFinalize(reason: String = "force") {
        let text = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && text.count >= config.minimumSentenceLength {
            let now = Date()
            let dt = now.timeIntervalSince(lastFinalizedTimestamp)
            if text != lastFinalizedText || dt > config.duplicateSuppressionWindow {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.sentenceDetector(self,
                                                    didFinalizeSentence: text,
                                                    reason: reason)
                }
                lastFinalizedText = text
                lastFinalizedTimestamp = now
            }
        }
        // We do NOT immediately call super.stop() here because `stop()` itself will flush remainder then call super.stop().
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
    
    // MARK: - Core “Incremental” Logic
    
    private func _processTranscriptCustom(_ transcript: String) {
        // 1) Trim whitespace/newlines
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        // 2) If nothing changed since last call, do nothing.
        if clean == fullTranscriptSoFar {
            return
        }
        
        // 3) Notify delegate of a “partial” update (for UI feedback).
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sentenceDetector(self, didDetectPartial: clean)
        }
        
        // 4) Determine “what just got appended.”
        let oldFull = fullTranscriptSoFar
        fullTranscriptSoFar = clean
        
        let newSegment: String
        if clean.hasPrefix(oldFull) {
            // If the new transcript literally starts with the old one, only take the suffix.
            let startIndex = clean.index(oldFull.endIndex, offsetBy: 0)
            newSegment = String(clean[startIndex...])
        } else {
            // Otherwise (e.g. punctuation adjustments), treat the entire clean string as “new.”
            newSegment = clean
        }
        
        // 5) Build a “collector” string = any leftover tail + what’s just been appended.
        var collector = remainder + newSegment
        
        // 6) Scan `collector` char-by-char, finalizing each time we hit “.”, “?”, or “!”.
        var sentencesToEmit: [String] = []
        var temp = ""
        
        for char in collector {
            temp.append(char)
            if [".", "?", "!"].contains(char) {
                let trimmed = temp.trimmingCharacters(in: .whitespacesAndNewlines)
                // Only accept this as a full sentence if it’s at least `minimumSentenceLength`
                // and not a known abbreviation/decimal.
                if trimmed.count >= config.minimumSentenceLength && !_isLikelyAbbreviation(trimmed) {
                    sentencesToEmit.append(trimmed)
                }
                temp = ""
            }
        }
        
        // 7) Whatever’s still in `temp` after the last punctuation becomes the new `remainder`.
        remainder = temp.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 8) Emit each complete sentence in order, applying duplicate‐suppression.
        for sentence in sentencesToEmit {
            let now = Date()
            let dt = now.timeIntervalSince(lastFinalizedTimestamp)
            if sentence != lastFinalizedText || dt > config.duplicateSuppressionWindow {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.sentenceDetector(self,
                                                    didFinalizeSentence: sentence,
                                                    reason: "punctuation-detected")
                }
                lastFinalizedText = sentence
                lastFinalizedTimestamp = now
            }
        }
    }
    
    // MARK: - Abbreviation / Decimal Detection
    
    private func _isLikelyAbbreviation(_ text: String) -> Bool {
        
        // 0) If the string has “digits.dot.digits <space>words + period” at its end, skip it
        let splitDecimalPattern = #"\b\d+\.\d+\s+[A-Za-z]+\.\s*$"#
        if _matchesPattern(text, pattern: splitDecimalPattern) {
            return true
        }

        let commonAbbreviations = [
            // Titles/honorifics
            "Dr.", "Mr.", "Mrs.", "Ms.", "Prof.", "Sr.", "Jr.", "Drs.",
            // Business/legal
            "Inc.", "Corp.", "Ltd.", "Co.", "LLC.", "L.L.C.", "P.C.", "L.P.", "LP.",
            // Academic degrees
            "Ph.D.", "M.D.", "B.A.", "M.A.", "M.S.", "B.S.", "M.B.A.", "J.D.", "LL.M.",
            "D.D.S.", "Pharm.D.", "Ed.D.", "Psy.D.",
            // Common
            "etc.", "vs.", "e.g.", "i.e.", "cf.", "viz.", "et al.", "ibid.",
            // Geographic/political
            "U.S.", "U.K.", "U.N.", "E.U.", "N.Y.", "L.A.", "D.C.", "N.J.", "Ca.",
            "N.H.", "R.I.", "Mass.", "Conn.", "Del.", "Md.", "Va.", "N.C.", "S.C.",
            "Ga.", "Fla.", "Ala.", "Miss.", "Tenn.", "Ky.", "Ohio", "Ind.", "Ill.",
            "Mich.", "Wis.", "Minn.", "Iowa", "Mo.", "Ark.", "La.", "Okla.", "Tex.",
            "N.M.", "Ariz.", "Colo.", "Utah", "Nev.", "Calif.", "Ore.", "Wash.",
            "Alaska", "Hawaii",
            // Months/time
            "Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.", "Jul.", "Aug.",
            "Sep.", "Sept.", "Oct.", "Nov.", "Dec.",
            "Mon.", "Tue.", "Wed.", "Thu.", "Fri.", "Sat.", "Sun.",
            "a.m.", "p.m.", "A.M.", "P.M.",
            // Measurements/units
            "in.", "ft.", "yd.", "mi.", "oz.", "lb.", "lbs.", "kg.", "cm.", "mm.",
            "m.", "km.", "mph", "kph", "sq.", "cu.",
            // Currency/financial
            "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF",
            // Tech/internet
            "www.", "http.", "https.", "ftp.", "IP.", "URL.", "HTML.", "CSS.", "JS.",
            // Miscellaneous
            "No.", "nos.", "#.", "Vol.", "Ch.", "Chap.", "pg.", "pp.", "fig.", "Fig.",
            "Ref.", "refs.", "App.", "Sec.", "min.", "max.", "approx.", "est."
        ]
        
        // 1) If it ends with a known “abbreviation.”, skip
        for a in commonAbbreviations {
            if text.hasSuffix(a) {
                return true
            }
        }
        
        // 2) Percentage patterns (e.g. “69.23%.”)
        let percentPattern = #"\d+\.?\d*%\.$"#
        if _matchesPattern(text, pattern: percentPattern) { return true }
        
        // 3) Decimal numbers (e.g. “3.14.”)
        let decimalPattern = #"\b\d+\.\d+\.?$"#
        if _matchesPattern(text, pattern: decimalPattern) { return true }
        
        // 4) Numbered lists (“1.”, “2.”, etc.)
        let numberedListPattern = #"\b\d{1,3}\.$"#
        if _matchesPattern(text, pattern: numberedListPattern) { return true }
        
        // 5) Version strings (“v1.2.3.”, “iOS 16.4.”)
        let versionPattern = #"\b(v|version|iOS|macOS|Android)\s*\d+(\.\d+)*\.$"#
        if _matchesPattern(text, pattern: versionPattern) { return true }
        
        // 6) Currency (“$123.45.”, “€99.99.”)
        let currencyPattern = #"[\$€£¥]\d+\.\d{2}\.$"#
        if _matchesPattern(text, pattern: currencyPattern) { return true }
        
        // 7) Time (“3:30.”, “12:45.”)
        let timePattern = #"\b\d{1,2}:\d{2}\.?$"#
        if _matchesPattern(text, pattern: timePattern) { return true }
        
        // 8) IP addresses (“192.168.1.1.”)
        let ipPattern = #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.?$"#
        if _matchesPattern(text, pattern: ipPattern) { return true }
        
        // 9) Scientific notation (“6.022e23.”)
        let sciPattern = #"\b\d+\.?\d*[eE][+-]?\d+\.?$"#
        if _matchesPattern(text, pattern: sciPattern) { return true }
        
        return false
    }
    
    /// Simple regex‐matcher helper
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
    
    /// Returns internal state for debugging
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
    
    /// Analyze a single string for debugging
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
