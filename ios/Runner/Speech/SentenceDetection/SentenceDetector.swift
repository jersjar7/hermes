// ios/Runner/Speech/SentenceDetection/SentenceDetector.swift

import Foundation

/// Delegate protocol for sentence detection events
protocol SentenceDetectorDelegate: AnyObject {
    func sentenceDetector(_ detector: SentenceDetector, didDetectPartial text: String)
    func sentenceDetector(_ detector: SentenceDetector, didFinalizeSentence text: String, reason: String)
    func sentenceDetector(_ detector: SentenceDetector, didEncounterError error: Error)
}

/// Core coordinator for sentence boundary detection
/// Orchestrates pattern matching and timer management
class SentenceDetector {
    
    // MARK: - Properties
    
    weak var delegate: SentenceDetectorDelegate?
    private let config: SentenceDetectionConfig
    
    // Components
    private let patternMatcher: SentencePatternMatcher
    private let timerManager: SentenceTimerManager
    
    // State
    private var currentTranscript: String = ""
    private var hasStartedSegment: Bool = false
    
    // 🆕 OPTIMIZATION: Track last finalized content to prevent duplicates
    private var lastFinalizedText: String = ""
    private var lastFinalizedTimestamp: Date = Date.distantPast
    
    // Thread safety
    private let queue = DispatchQueue(label: "hermes.sentence-detector", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(config: SentenceDetectionConfig = .default, delegate: SentenceDetectorDelegate? = nil) {
        self.config = config.validated()
        self.delegate = delegate
        
        // Initialize components
        self.patternMatcher = SentencePatternMatcher(config: self.config)
        self.timerManager = SentenceTimerManager(config: self.config)
        
        // Set up timer delegate
        self.timerManager.delegate = self
        
        print("🎯 [SentenceDetector] Initialized with config: \(self.config.debugDescription)")
    }
    
    deinit {
        stop()
        print("🗑️ [SentenceDetector] Deallocated")
    }
    
    // MARK: - Public Interface
    
    /// Process a new partial transcript from speech recognition
    func processPartialTranscript(_ transcript: String, isFinal: Bool = false) {
        queue.async { [weak self] in
            self?._processTranscript(transcript, isFinal: isFinal)
        }
    }
    
    /// Force finalization of current segment
    func forceFinalize(reason: String = "manual") {
        queue.async { [weak self] in
            self?._finalizeCurrent(reason: reason)
        }
    }
    
    /// Stop detection and clean up
    func stop() {
        queue.async { [weak self] in
            self?._cleanup()
        }
    }
    
    /// Reset detector state
    func reset() {
        queue.async { [weak self] in
            self?._reset()
        }
    }
    
    // MARK: - Core Processing Logic
    
    private func _processTranscript(_ transcript: String, isFinal: Bool) {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty transcripts
        guard !cleanedTranscript.isEmpty else {
            return
        }
        
        // 🆕 OPTIMIZATION: Handle unchanged transcripts more intelligently
        guard cleanedTranscript != currentTranscript else {
            // If it's an iOS final for the same content, force finalize
            if isFinal && !cleanedTranscript.isEmpty {
                _finalizeCurrent(reason: "ios-final-duplicate")
            }
            return
        }
        
        // Initialize segment if this is new content
        if !hasStartedSegment {
            _startNewSegment()
        }
        
        // Update current state
        currentTranscript = cleanedTranscript
        
        // Send partial update to delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sentenceDetector(self, didDetectPartial: cleanedTranscript)
        }
        
        // Handle forced finalization from iOS
        if isFinal {
            _finalizeCurrent(reason: "ios-final")
            return
        }
        
        // 🆕 OPTIMIZATION: Enhanced pattern detection with multiple criteria
        if _shouldFinalize(text: cleanedTranscript) {
            let reason = patternMatcher.detectionReason(for: cleanedTranscript) ?? "pattern"
            _finalizeCurrent(reason: reason)
            return
        }
        
        // Reset stability timer since content changed
        timerManager.resetStabilityTimer()
    }
    
    // 🆕 OPTIMIZATION: Enhanced finalization criteria
    private func _shouldFinalize(text: String) -> Bool {
        // Check for punctuation-based boundaries
        if patternMatcher.hasNaturalBreak(in: text) {
            return true
        }
        
        // Check for length-based splitting (long sentences)
        if text.count > config.maximumLength && config.maximumLength > 0 {
            return true
        }
        
        // Check for time-based splitting (very long segments)
        let segmentDuration = timerManager.currentSegmentDuration
        if segmentDuration > (config.maxSegmentDuration * 0.8) && text.count >= config.minimumLength {
            return true
        }
        
        return false
    }
    
    private func _startNewSegment() {
        hasStartedSegment = true
        timerManager.startSegmentTiming()
        print("🚀 [SentenceDetector] Started new segment")
    }
    
    private func _finalizeCurrent(reason: String) {
        guard !currentTranscript.isEmpty else {
            return
        }
        
        // 🆕 OPTIMIZATION: Prevent duplicate finalizations
        let now = Date()
        let timeSinceLastFinalization = now.timeIntervalSince(lastFinalizedTimestamp)
        
        // Skip if we finalized the exact same text recently (within 2 seconds)
        if currentTranscript == lastFinalizedText && timeSinceLastFinalization < 2.0 {
            print("🔄 [SentenceDetector] Skipping duplicate final: '\(currentTranscript.prefix(30))...' (reason: \(reason))")
            _resetForNextSegment()
            return
        }
        
        // 🆕 OPTIMIZATION: Skip if the new text is just a minor variation of the last finalized text
        if _isMinorVariation(of: lastFinalizedText, compared: currentTranscript) && timeSinceLastFinalization < 5.0 {
            print("🔄 [SentenceDetector] Skipping minor variation: '\(currentTranscript.prefix(30))...' (reason: \(reason))")
            _resetForNextSegment()
            return
        }
        
        let finalText = currentTranscript
        print("✅ [SentenceDetector] Finalizing: '\(finalText.prefix(50))...' (reason: \(reason))")
        
        // Update tracking variables
        lastFinalizedText = finalText
        lastFinalizedTimestamp = now
        
        // Send finalized segment to delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sentenceDetector(self, didFinalizeSentence: finalText, reason: reason)
        }
        
        // Reset for next segment
        _resetForNextSegment()
    }
    
    // 🆕 OPTIMIZATION: Check if text is just a minor variation of previous text
    private func _isMinorVariation(of previousText: String, compared currentText: String) -> Bool {
        // Skip check if either text is empty
        guard !previousText.isEmpty && !currentText.isEmpty else { return false }
        
        // If current text is just previous text with punctuation added
        let currentWithoutPunctuation = currentText.replacingOccurrences(of: "[.!?]", with: "", options: .regularExpression)
        let previousWithoutPunctuation = previousText.replacingOccurrences(of: "[.!?]", with: "", options: .regularExpression)
        
        if currentWithoutPunctuation.lowercased() == previousWithoutPunctuation.lowercased() {
            return true
        }
        
        // If current text is just previous text with minor additions (< 20% change)
        let commonPrefix = currentText.commonPrefix(with: previousText)
        if commonPrefix.count > 0 {
            let changeRatio = Double(abs(currentText.count - previousText.count)) / Double(max(currentText.count, previousText.count))
            return changeRatio < 0.2
        }
        
        return false
    }
    
    private func _resetForNextSegment() {
        currentTranscript = ""
        hasStartedSegment = false
        timerManager.stopAllTimers()
    }
    
    private func _reset() {
        _resetForNextSegment()
        // Don't reset lastFinalizedText here to maintain duplicate detection across resets
    }
    
    private func _cleanup() {
        // Finalize any pending content
        if !currentTranscript.isEmpty {
            _finalizeCurrent(reason: "cleanup")
        }
        _reset()
    }
}

// MARK: - SentenceTimerManagerDelegate

extension SentenceDetector: SentenceTimerManagerDelegate {
    
    func timerManager(_ manager: SentenceTimerManager, didTriggerStabilityTimeout: Void) {
        queue.async { [weak self] in
            print("⏱️ [SentenceDetector] Stability timeout - finalizing")
            self?._finalizeCurrent(reason: "stability-timeout")
        }
    }
    
    func timerManager(_ manager: SentenceTimerManager, didTriggerMaxDurationTimeout: Void) {
        queue.async { [weak self] in
            print("⏰ [SentenceDetector] Max duration timeout - finalizing")
            self?._finalizeCurrent(reason: "max-duration")
        }
    }
}

// MARK: - Debug Support

extension SentenceDetector {
    
    /// Get current state for debugging
    var debugInfo: [String: Any] {
        return [
            "currentTranscript": currentTranscript,
            "hasStartedSegment": hasStartedSegment,
            "lastFinalizedText": lastFinalizedText,
            "lastFinalizedTimestamp": lastFinalizedTimestamp.timeIntervalSince1970,
            "timerManager": timerManager.debugInfo,
            "config": config.toDictionary()
        ]
    }
    
    /// Analyze text without processing (for testing)
    func analyzeText(_ text: String) -> [String: Any] {
        var analysis = patternMatcher.analyzeText(text)
        analysis["shouldFinalize"] = _shouldFinalize(text: text)
        analysis["isMinorVariation"] = _isMinorVariation(of: lastFinalizedText, compared: text)
        return analysis
    }
}
