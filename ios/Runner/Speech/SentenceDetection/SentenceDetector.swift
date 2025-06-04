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
        
        // Handle unchanged transcripts
        guard cleanedTranscript != currentTranscript else {
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
        
        // Check for natural pattern boundaries
        if patternMatcher.hasNaturalBreak(in: cleanedTranscript) {
            let reason = patternMatcher.detectionReason(for: cleanedTranscript) ?? "pattern"
            _finalizeCurrent(reason: reason)
            return
        }
        
        // Reset stability timer since content changed
        timerManager.resetStabilityTimer()
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
        
        let finalText = currentTranscript
        print("✅ [SentenceDetector] Finalizing: '\(finalText.prefix(50))...' (reason: \(reason))")
        
        // Send finalized segment to delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sentenceDetector(self, didFinalizeSentence: finalText, reason: reason)
        }
        
        // Reset for next segment
        _reset()
    }
    
    private func _reset() {
        currentTranscript = ""
        hasStartedSegment = false
        timerManager.stopAllTimers()
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
            "timerManager": timerManager.debugInfo,
            "config": config.toDictionary()
        ]
    }
    
    /// Analyze text without processing (for testing)
    func analyzeText(_ text: String) -> [String: Any] {
        return patternMatcher.analyzeText(text)
    }
}//
//  Untitled.swift
//  Runner
//
//  Created by Jerson on 6/4/25.
//

