// ios/Runner/Speech/SentenceDetection/SentenceTimerManager.swift

import Foundation

/// Delegate protocol for timer events
protocol SentenceTimerManagerDelegate: AnyObject {
    func timerManager(_ manager: SentenceTimerManager, didTriggerStabilityTimeout: Void)
    func timerManager(_ manager: SentenceTimerManager, didTriggerMaxDurationTimeout: Void)
}

/// Manages timing logic for sentence detection
/// Handles stability timeout and maximum duration timeout
class SentenceTimerManager {
    
    // MARK: - Properties
    
    private let config: SentenceDetectionConfig
    weak var delegate: SentenceTimerManagerDelegate?
    
    // Timer state
    private var stabilityTimer: Timer?
    private var maxDurationTimer: Timer?
    private var segmentStartTime: Date?
    
    // 🆕 OPTIMIZATION: Enhanced timing tracking
    private var lastResetTime: Date?
    private var stabilityResetCount: Int = 0
    private var averageStabilityInterval: TimeInterval = 0
    
    // Thread safety
    private let queue = DispatchQueue(label: "hermes.timer-manager", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(config: SentenceDetectionConfig, delegate: SentenceTimerManagerDelegate? = nil) {
        self.config = config
        self.delegate = delegate
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - Public Interface
    
    /// Start timing for a new segment
    func startSegmentTiming() {
        queue.async { [weak self] in
            self?._startSegmentTiming()
        }
    }
    
    /// Reset stability timer (called when transcript changes)
    func resetStabilityTimer() {
        queue.async { [weak self] in
            self?._resetStabilityTimer()
        }
    }
    
    /// Stop all timers and reset state
    func stopAllTimers() {
        queue.async { [weak self] in
            self?._stopAllTimers()
        }
    }
    
    /// Check if timers are currently active
    var hasActiveTimers: Bool {
        return stabilityTimer != nil || maxDurationTimer != nil
    }
    
    /// Get current segment duration
    var currentSegmentDuration: TimeInterval {
        guard let startTime = segmentStartTime else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
    
    // 🆕 OPTIMIZATION: Advanced timing metrics
    
    /// Get average time between stability resets (useful for tuning)
    var averageStabilityResetInterval: TimeInterval {
        return averageStabilityInterval
    }
    
    /// Get number of stability resets for current segment
    var stabilityResetCountForSegment: Int {
        return stabilityResetCount
    }
    
    /// Check if segment is approaching max duration (80% threshold)
    var isApproachingMaxDuration: Bool {
        let duration = currentSegmentDuration
        return duration > (config.maxSegmentDuration * 0.8)
    }
    
    // MARK: - Private Implementation
    
    private func _startSegmentTiming() {
        // Record start time
        segmentStartTime = Date()
        
        // Reset counters for new segment
        stabilityResetCount = 0
        averageStabilityInterval = 0
        lastResetTime = nil
        
        // Start max duration timer
        _startMaxDurationTimer()
        
        print("🕐 [TimerManager] Started segment timing (maxDuration: \(config.maxSegmentDuration)s)")
    }
    
    private func _resetStabilityTimer() {
        // 🆕 OPTIMIZATION: Track stability reset metrics
        let now = Date()
        if let lastReset = lastResetTime {
            let interval = now.timeIntervalSince(lastReset)
            stabilityResetCount += 1
            
            // Calculate running average of stability intervals
            if averageStabilityInterval == 0 {
                averageStabilityInterval = interval
            } else {
                averageStabilityInterval = (averageStabilityInterval + interval) / 2.0
            }
            
            print("📊 [TimerManager] Stability reset #\(stabilityResetCount), interval: \(String(format: "%.2f", interval))s, avg: \(String(format: "%.2f", averageStabilityInterval))s")
        }
        lastResetTime = now
        
        // Cancel existing stability timer
        stabilityTimer?.invalidate()
        
        // 🆕 OPTIMIZATION: Adaptive stability timeout based on speech pattern
        let adaptiveTimeout = _calculateAdaptiveStabilityTimeout()
        
        // Start new stability timer
        stabilityTimer = Timer.scheduledTimer(withTimeInterval: adaptiveTimeout, repeats: false) { [weak self] _ in
            self?._onStabilityTimeout()
        }
        
        print("⏱️ [TimerManager] Reset stability timer (\(String(format: "%.2f", adaptiveTimeout))s)")
    }
    
    /// 🆕 OPTIMIZATION: Calculate adaptive stability timeout based on speech patterns
    private func _calculateAdaptiveStabilityTimeout() -> TimeInterval {
        var timeout = config.stabilityTimeout
        
        // If we've had many rapid resets, user might be speaking quickly
        if stabilityResetCount > 5 && averageStabilityInterval < 0.5 {
            timeout = max(timeout * 0.7, 0.5) // Reduce timeout for fast speakers
            print("🏃 [TimerManager] Fast speech detected, reduced timeout to \(String(format: "%.2f", timeout))s")
        }
        
        // If we're approaching max duration, be more aggressive
        if isApproachingMaxDuration {
            timeout = max(timeout * 0.6, 0.3) // More aggressive timeout near limit
            print("⏰ [TimerManager] Approaching max duration, reduced timeout to \(String(format: "%.2f", timeout))s")
        }
        
        // If resets are very infrequent, user might be speaking slowly
        if stabilityResetCount > 2 && averageStabilityInterval > 2.0 {
            timeout = min(timeout * 1.3, config.maxSegmentDuration / 3) // Increase timeout for slow speakers
            print("🐌 [TimerManager] Slow speech detected, increased timeout to \(String(format: "%.2f", timeout))s")
        }
        
        return timeout
    }
    
    private func _startMaxDurationTimer() {
        // Cancel existing max duration timer
        maxDurationTimer?.invalidate()
        
        // Start new max duration timer
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: config.maxSegmentDuration, repeats: false) { [weak self] _ in
            self?._onMaxDurationTimeout()
        }
        
        print("⏰ [TimerManager] Started max duration timer (\(config.maxSegmentDuration)s)")
    }
    
    private func _stopAllTimers() {
        stabilityTimer?.invalidate()
        stabilityTimer = nil
        
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        
        // Reset state but preserve metrics for analysis
        segmentStartTime = nil
        
        print("🛑 [TimerManager] Stopped all timers (had \(stabilityResetCount) stability resets)")
    }
    
    // MARK: - Timer Callbacks
    
    private func _onStabilityTimeout() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let finalResetCount = self.stabilityResetCount
            let avgInterval = self.averageStabilityInterval
            
            print("⏱️ [TimerManager] Stability timeout triggered (after \(finalResetCount) resets, avg interval: \(String(format: "%.2f", avgInterval))s)")
            
            // Clear the timer reference
            self.stabilityTimer = nil
            
            // Notify delegate on main thread
            DispatchQueue.main.async {
                self.delegate?.timerManager(self, didTriggerStabilityTimeout: ())
            }
        }
    }
    
    private func _onMaxDurationTimeout() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let finalDuration = self.currentSegmentDuration
            let finalResetCount = self.stabilityResetCount
            
            print("⏰ [TimerManager] Max duration timeout triggered (duration: \(String(format: "%.2f", finalDuration))s, resets: \(finalResetCount))")
            
            // Clear the timer reference
            self.maxDurationTimer = nil
            
            // Notify delegate on main thread
            DispatchQueue.main.async {
                self.delegate?.timerManager(self, didTriggerMaxDurationTimeout: ())
            }
        }
    }
    
    // MARK: - State Queries
    
    /// Check if stability timer is active
    var isStabilityTimerActive: Bool {
        return stabilityTimer != nil
    }
    
    /// Check if max duration timer is active
    var isMaxDurationTimerActive: Bool {
        return maxDurationTimer != nil
    }
    
    /// Get remaining time for stability timer
    var stabilityTimeRemaining: TimeInterval? {
        guard let timer = stabilityTimer else {
            return nil
        }
        return max(0, timer.fireDate.timeIntervalSinceNow)
    }
    
    /// Get remaining time for max duration timer
    var maxDurationTimeRemaining: TimeInterval? {
        guard let timer = maxDurationTimer else {
            return nil
        }
        return max(0, timer.fireDate.timeIntervalSinceNow)
    }
    
    /// 🆕 OPTIMIZATION: Get percentage of max duration elapsed
    var maxDurationProgress: Double {
        let elapsed = currentSegmentDuration
        return min(1.0, elapsed / config.maxSegmentDuration)
    }
}

// MARK: - Debug Support

extension SentenceTimerManager {
    
    /// Get current timer state for debugging
    var debugInfo: [String: Any] {
        return [
            "hasActiveTimers": hasActiveTimers,
            "stabilityTimerActive": isStabilityTimerActive,
            "maxDurationTimerActive": isMaxDurationTimerActive,
            "currentSegmentDuration": currentSegmentDuration,
            "stabilityTimeRemaining": stabilityTimeRemaining ?? 0,
            "maxDurationTimeRemaining": maxDurationTimeRemaining ?? 0,
            "maxDurationProgress": maxDurationProgress,
            "stabilityResetCount": stabilityResetCount,
            "averageStabilityInterval": averageStabilityInterval,
            "isApproachingMaxDuration": isApproachingMaxDuration,
            "config": [
                "stabilityTimeout": config.stabilityTimeout,
                "maxSegmentDuration": config.maxSegmentDuration
            ]
        ]
    }
    
    /// Get human-readable timer status
    var statusDescription: String {
        var status: [String] = []
        
        if isStabilityTimerActive {
            let remaining = stabilityTimeRemaining ?? 0
            status.append("Stability: \(String(format: "%.1f", remaining))s")
        }
        
        if isMaxDurationTimerActive {
            let remaining = maxDurationTimeRemaining ?? 0
            let progress = Int(maxDurationProgress * 100)
            status.append("MaxDuration: \(String(format: "%.1f", remaining))s (\(progress)%)")
        }
        
        if status.isEmpty {
            return "No active timers"
        }
        
        let baseStatus = status.joined(separator: ", ")
        
        if stabilityResetCount > 0 {
            return "\(baseStatus) [Resets: \(stabilityResetCount)]"
        }
        
        return baseStatus
    }
    
    /// 🆕 OPTIMIZATION: Get performance metrics for tuning
    var performanceMetrics: [String: Any] {
        return [
            "totalResets": stabilityResetCount,
            "averageResetInterval": averageStabilityInterval,
            "segmentDuration": currentSegmentDuration,
            "durationProgress": maxDurationProgress,
            "resetsPerSecond": stabilityResetCount > 0 ? Double(stabilityResetCount) / max(1.0, currentSegmentDuration) : 0,
            "speechPattern": _analyzeSpeechPattern()
        ]
    }
    
    /// Analyze speech pattern based on reset frequency
    private func _analyzeSpeechPattern() -> String {
        if stabilityResetCount == 0 {
            return "silent"
        }
        
        let resetsPerSecond = Double(stabilityResetCount) / max(1.0, currentSegmentDuration)
        
        if resetsPerSecond > 3.0 {
            return "very-fast"
        } else if resetsPerSecond > 2.0 {
            return "fast"
        } else if resetsPerSecond > 1.0 {
            return "normal"
        } else if resetsPerSecond > 0.5 {
            return "slow"
        } else {
            return "very-slow"
        }
    }
}
