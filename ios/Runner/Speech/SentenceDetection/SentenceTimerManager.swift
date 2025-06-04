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
    
    // MARK: - Private Implementation
    
    private func _startSegmentTiming() {
        // Record start time
        segmentStartTime = Date()
        
        // Start max duration timer
        _startMaxDurationTimer()
        
        print("🕐 [TimerManager] Started segment timing (maxDuration: \(config.maxSegmentDuration)s)")
    }
    
    private func _resetStabilityTimer() {
        // Cancel existing stability timer
        stabilityTimer?.invalidate()
        
        // Start new stability timer
        stabilityTimer = Timer.scheduledTimer(withTimeInterval: config.stabilityTimeout, repeats: false) { [weak self] _ in
            self?._onStabilityTimeout()
        }
        
        print("⏱️ [TimerManager] Reset stability timer (\(config.stabilityTimeout)s)")
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
        
        segmentStartTime = nil
        
        print("🛑 [TimerManager] Stopped all timers")
    }
    
    // MARK: - Timer Callbacks
    
    private func _onStabilityTimeout() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            print("⏱️ [TimerManager] Stability timeout triggered")
            
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
            
            print("⏰ [TimerManager] Max duration timeout triggered")
            
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
        return timer.fireDate.timeIntervalSinceNow
    }
    
    /// Get remaining time for max duration timer
    var maxDurationTimeRemaining: TimeInterval? {
        guard let timer = maxDurationTimer else {
            return nil
        }
        return timer.fireDate.timeIntervalSinceNow
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
            status.append("MaxDuration: \(String(format: "%.1f", remaining))s")
        }
        
        if status.isEmpty {
            return "No active timers"
        }
        
        return status.joined(separator: ", ")
    }
}//
//  SentenceTimerManager.swift
//  Runner
//
//  Created by Jerson on 6/4/25.
//

