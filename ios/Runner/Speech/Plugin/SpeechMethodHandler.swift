// ios/Runner/Speech/Plugin/SpeechMethodHandler.swift

import Flutter
import Foundation
import Speech

/// Handles Flutter method channel calls for speech recognition
/// Uses PURE PATTERN-BASED sentence detection (NO TIMERS!)
@available(iOS 16.0, *)
class SpeechMethodHandler: NSObject {
    
    // MARK: - Properties
    
    private let methodChannel: FlutterMethodChannel
    private let eventSender: SpeechEventSender
    
    // Speech components
    private var speechManager: SpeechRecognitionManager?
    
    // 🆕 NEW: Pure pattern-based sentence detector (NO TIMERS!)
    private var purePatternDetector: PurePatternSentenceDetector?
    
    // State
    private var isInitialized = false
    private var isRecognitionActive = false
    private var currentLocale = "en-US"
    
    // MARK: - Initialization
    
    init(binaryMessenger: FlutterBinaryMessenger, eventSender: SpeechEventSender) {
        self.methodChannel = FlutterMethodChannel(
            name: "hermes/continuous_speech",
            binaryMessenger: binaryMessenger
        )
        self.eventSender = eventSender
        
        super.init()
        
        methodChannel.setMethodCallHandler(handleMethodCall)
        print("🎤 [MethodHandler] Method channel initialized with PURE PATTERN detection")
    }
    
    deinit {
        cleanup()
        print("🎤 [MethodHandler] Method handler deallocated")
    }
    
    // MARK: - Method Channel Handler
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Method call: \(call.method)")
        
        switch call.method {
        case "isAvailable":
            handleIsAvailable(result: result)
            
        case "initialize":
            handleInitialize(arguments: call.arguments, result: result)
            
        case "startContinuousRecognition":
            handleStartRecognition(arguments: call.arguments, result: result)
            
        case "stopContinuousRecognition":
            handleStopRecognition(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Method Implementations
    
    private func handleIsAvailable(result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Checking speech recognition availability...")
        
        // Check speech recognition authorization
        let speechAuth = SFSpeechRecognizer.authorizationStatus()
        guard speechAuth != .denied && speechAuth != .restricted else {
            print("❌ [MethodHandler] Speech recognition denied or restricted")
            result(false)
            return
        }
        
        // Check if recognizer is available for current locale
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLocale)),
              recognizer.isAvailable else {
            print("❌ [MethodHandler] Speech recognizer not available for locale: \(currentLocale)")
            result(false)
            return
        }
        
        print("✅ [MethodHandler] Speech recognition available")
        result(true)
    }
    
    private func handleInitialize(arguments: Any?, result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Initializing TIMER-FREE speech recognition...")
        
        guard !isInitialized else {
            print("⚠️ [MethodHandler] Already initialized")
            result(true)
            return
        }
        
        // Parse configuration from Flutter
        let config = parseInitializeArguments(arguments)
        
        // Create speech recognition manager
        speechManager = SpeechRecognitionManager(config: config, delegate: self)
        
        // 🆕 NEW: Create pure pattern detector (NO TIMERS!)
        let detectorConfig = PurePatternSentenceDetector.Config.hermes
        purePatternDetector = PurePatternSentenceDetector(config: detectorConfig, delegate: self)
        
        print("✅ [MethodHandler] Created TIMER-FREE sentence detector")
        
        // Request permissions asynchronously
        Task {
            let granted = await speechManager?.requestPermissions() ?? false
            
            DispatchQueue.main.async { [weak self] in
                if granted {
                    self?.isInitialized = true
                    self?.eventSender.sendStatusUpdate("initialized")
                    print("✅ [MethodHandler] TIMER-FREE speech recognition initialized")
                    result(true)
                } else {
                    self?.eventSender.sendError(message: "Speech recognition permissions denied", code: "PERMISSION_DENIED")
                    print("❌ [MethodHandler] Speech recognition permissions denied")
                    result(false)
                }
            }
        }
    }
    
    private func handleStartRecognition(arguments: Any?, result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Starting PURE PATTERN continuous recognition...")
        
        guard isInitialized, let speechManager = speechManager else {
            let error = "Speech recognition not initialized"
            eventSender.sendError(message: error, code: "NOT_INITIALIZED")
            result(FlutterError(code: "NOT_INITIALIZED", message: error, details: nil))
            return
        }
        
        guard !isRecognitionActive else {
            print("⚠️ [MethodHandler] Recognition already active")
            result(nil)
            return
        }
        
        // Parse recognition configuration
        let config = parseRecognitionArguments(arguments)
        speechManager.updateConfig(config)
        
        // Start recognition
        Task {
            do {
                try await speechManager.startRecognition()
                
                DispatchQueue.main.async { [weak self] in
                    self?.isRecognitionActive = true
                    self?.eventSender.sendStatusUpdate("started")
                    print("✅ [MethodHandler] PURE PATTERN recognition started successfully")
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    let errorMessage = "Failed to start recognition: \(error.localizedDescription)"
                    self?.eventSender.sendError(message: errorMessage, code: "START_FAILED")
                    print("❌ [MethodHandler] \(errorMessage)")
                    result(FlutterError(code: "START_FAILED", message: errorMessage, details: nil))
                }
            }
        }
    }
    
    private func handleStopRecognition(result: @escaping FlutterResult) {
        print("🎤 [MethodHandler] Stopping PURE PATTERN recognition...")
        
        guard isRecognitionActive else {
            print("⚠️ [MethodHandler] Recognition not active")
            result(nil)
            return
        }
        
        // Stop speech manager
        speechManager?.stopRecognition()
        
        // 🆕 Force finalize any pending content (only if substantial)
        purePatternDetector?.forceFinalize(reason: "stop-requested")
        
        isRecognitionActive = false
        eventSender.sendStatusUpdate("stopped")
        
        print("✅ [MethodHandler] PURE PATTERN recognition stopped")
        result(nil)
    }
    
    // MARK: - Argument Parsing
    
    private func parseInitializeArguments(_ arguments: Any?) -> SpeechRecognitionConfig {
        guard let args = arguments as? [String: Any] else {
            print("🎤 [MethodHandler] No initialization arguments, using default config")
            return .hermes
        }
        
        // Extract locale
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        return SpeechRecognitionConfig.fromDictionary(args)
    }
    
    private func parseRecognitionArguments(_ arguments: Any?) -> SpeechRecognitionConfig {
        guard let args = arguments as? [String: Any] else {
            print("🎤 [MethodHandler] No recognition arguments, using current config")
            return speechManager?.currentConfig ?? .hermes
        }
        
        // Update locale if provided
        if let locale = args["locale"] as? String {
            currentLocale = locale
        }
        
        return SpeechRecognitionConfig.fromDictionary(args)
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        if isRecognitionActive {
            speechManager?.stopRecognition()
            purePatternDetector?.forceFinalize(reason: "cleanup")
        }
        
        speechManager = nil
        purePatternDetector = nil
        isInitialized = false
        isRecognitionActive = false
        
        methodChannel.setMethodCallHandler(nil)
    }
}

// MARK: - SpeechRecognitionManagerDelegate

@available(iOS 16.0, *)
extension SpeechMethodHandler: SpeechRecognitionManagerDelegate {
    
    func speechManager(_ manager: SpeechRecognitionManager, didReceivePartialResult text: String, confidence: Double) {
        print("📝 [MethodHandler] Partial from iOS: '\(String(text.prefix(50)))...'")
        
        // 🆕 NEW: Feed ALL results to pure pattern detector
        // Let the detector decide based on CONTENT, not iOS timing
        purePatternDetector?.processTranscript(text, isFinal: false)
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didReceiveFinalResult text: String, confidence: Double) {
        print("📝 [MethodHandler] iOS marked as final: '\(String(text.prefix(50)))...'")
        
        // 🚨 CRITICAL CHANGE: Don't force finalize!
        // Let pattern detector analyze the content first
        // This prevents the multiple-transmission problem
        purePatternDetector?.processTranscript(text, isFinal: false)
        
        // 🎯 The pattern detector will decide if this is truly complete
        // based on linguistic patterns, not iOS's timing
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didChangeStatus status: SpeechRecognitionStatus) {
        eventSender.sendStatusUpdate("recognition-\(status.shortDescription)")
    }
    
    func speechManager(_ manager: SpeechRecognitionManager, didEncounterError error: Error) {
        eventSender.sendError(message: error.localizedDescription, code: "RECOGNITION_ERROR")
    }
}

// MARK: - SentenceDetectorDelegate (for PurePatternSentenceDetector)

@available(iOS 16.0, *)
extension SpeechMethodHandler: SentenceDetectorDelegate {
    
    func sentenceDetector(_ detector: SentenceDetector, didDetectPartial text: String) {
        // Send partial result to Flutter for UI updates
        print("📱 [MethodHandler] Sending partial to Flutter: '\(String(text.prefix(30)))...'")
        
        eventSender.sendRecognitionResult(
            transcript: text,
            isFinal: false,
            confidence: 1.0,
            locale: currentLocale
        )
    }
    
    func sentenceDetector(_ detector: SentenceDetector, didFinalizeSentence text: String, reason: String) {
        // 🎯 CRITICAL: Only send when pattern detector confirms COMPLETE sentence
        print("🎯 [MethodHandler] ✅ COMPLETE SENTENCE CONFIRMED: '\(String(text.prefix(50)))...' (reason: \(reason))")
        
        eventSender.sendRecognitionResult(
            transcript: text,
            isFinal: true,
            confidence: 1.0,
            locale: currentLocale,
            reason: reason
        )
        
        // 🆕 NEW: Add debug analysis to help tune the system
        if let pureDetector = detector as? PurePatternSentenceDetector {
            let analysis = pureDetector.analyzeText(text)
            print("🔍 [MethodHandler] Sentence analysis: \(analysis)")
        }
    }
    
    func sentenceDetector(_ detector: SentenceDetector, didEncounterError error: Error) {
        print("❌ [MethodHandler] Sentence detector error: \(error)")
        eventSender.sendError(message: error.localizedDescription, code: "SENTENCE_DETECTION_ERROR")
    }
}

// MARK: - Pure Pattern Sentence Detector Implementation

/// Pure pattern-based sentence detector - NO TIMERS!
/// Relies solely on linguistic patterns to detect complete sentences
class PurePatternSentenceDetector {
    
    // MARK: - Properties
    
    weak var delegate: SentenceDetectorDelegate?
    
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
