// ios/Runner/Speech/Support/SpeechLogger.swift

import Foundation
import os

/// Centralized logging system for speech recognition components
/// Provides structured logging with different levels and contexts
class SpeechLogger {
    
    // MARK: - Singleton
    
    static let shared = SpeechLogger()
    
    private init() {
        setupLogger()
    }
    
    // MARK: - Properties
    
    private var isEnabled = true
    private var logLevel: LogLevel = .info
    private var logToFile = false
    
    // iOS unified logging
    @available(iOS 10.0, *)
    private lazy var osLog = OSLog(subsystem: "com.hermes.speech", category: "recognition")
    
    // MARK: - Log Levels
    
    enum LogLevel: Int, CaseIterable {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        
        var emoji: String {
            switch self {
            case .verbose: return "💬"
            case .debug: return "🐛"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
        
        var name: String {
            switch self {
            case .verbose: return "VERBOSE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            }
        }
    }
    
    // MARK: - Component Context
    
    enum Component: String {
        case plugin = "Plugin"
        case recognition = "Recognition"
        case audio = "Audio"
        case permissions = "Permissions"
        case sentenceDetection = "SentenceDetection"
        case patternMatcher = "PatternMatcher"
        case timerManager = "TimerManager"
        case eventSender = "EventSender"
        case methodHandler = "MethodHandler"
    }
    
    // MARK: - Configuration
    
    func configure(level: LogLevel, enableFileLogging: Bool = false) {
        logLevel = level
        logToFile = enableFileLogging
        
        log(.info, component: .plugin, "Logger configured: level=\(level.name), fileLogging=\(enableFileLogging)")
    }
    
    func enable() {
        isEnabled = true
        log(.info, component: .plugin, "Logging enabled")
    }
    
    func disable() {
        log(.info, component: .plugin, "Logging disabled")
        isEnabled = false
    }
    
    // MARK: - Core Logging Methods
    
    func log(_ level: LogLevel, component: Component, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled && level.rawValue >= logLevel.rawValue else { return }
        
        let logMessage = formatMessage(level: level, component: component, message: message, file: file, function: function, line: line)
        
        // Console logging
        print(logMessage)
        
        // iOS unified logging (iOS 10+)
        if #available(iOS 10.0, *) {
            logToUnifiedLogging(level: level, message: logMessage)
        }
        
        // File logging (if enabled)
        if logToFile {
            writeToFile(logMessage)
        }
    }
    
    // MARK: - Convenience Methods
    
    func verbose(_ message: String, component: Component, file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, component: component, message, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, component: Component, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, component: component, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, component: Component, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, component: component, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, component: Component, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, component: component, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, component: Component, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " Error: \(error.localizedDescription)"
        }
        log(.error, component: component, fullMessage, file: file, function: function, line: line)
    }
    
    // MARK: - Specialized Logging
    
    func logRecognitionResult(transcript: String, isFinal: Bool, confidence: Double, component: Component = .recognition) {
        let resultType = isFinal ? "FINAL" : "PARTIAL"
        let truncatedTranscript = String(transcript.prefix(50))
        info("Recognition \(resultType): '\(truncatedTranscript)' (confidence: \(String(format: "%.2f", confidence)))", component: component)
    }
    
    func logSentenceDetection(text: String, reason: String, component: Component = .sentenceDetection) {
        let truncatedText = String(text.prefix(50))
        info("Sentence finalized: '\(truncatedText)' (reason: \(reason))", component: component)
    }
    
    func logTimerEvent(event: String, duration: TimeInterval, component: Component = .timerManager) {
        info("Timer \(event): \(String(format: "%.2f", duration))s", component: component)
    }
    
    func logAudioSetup(sampleRate: Double, bufferSize: Int, component: Component = .audio) {
        info("Audio configured: \(sampleRate)Hz, buffer: \(bufferSize)", component: component)
    }
    
    func logPermissionRequest(type: String, granted: Bool, component: Component = .permissions) {
        let status = granted ? "GRANTED" : "DENIED"
        info("Permission \(type): \(status)", component: component)
    }
    
    // MARK: - Private Implementation
    
    private func setupLogger() {
        #if DEBUG
        logLevel = .debug
        #else
        logLevel = .info
        #endif
        
        info("Speech Logger initialized", component: .plugin)
    }
    
    private func formatMessage(level: LogLevel, component: Component, message: String, file: String, function: String, line: Int) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let filename = URL(fileURLWithPath: file).lastPathComponent
        
        return "\(timestamp) \(level.emoji) [\(component.rawValue)] \(message) (\(filename):\(line))"
    }
    
    @available(iOS 10.0, *)
    private func logToUnifiedLogging(level: LogLevel, message: String) {
        switch level {
        case .verbose, .debug:
            os_log("%{public}@", log: osLog, type: .debug, message)
        case .info:
            os_log("%{public}@", log: osLog, type: .info, message)
        case .warning:
            os_log("%{public}@", log: osLog, type: .default, message)
        case .error:
            os_log("%{public}@", log: osLog, type: .error, message)
        }
    }
    
    private func writeToFile(_ message: String) {
        // File logging implementation
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let logFileURL = documentsPath.appendingPathComponent("hermes_speech.log")
        let logEntry = "\(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: logFileURL)
            }
        }
    }
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Global Convenience Functions

/// Global logging functions for easy access across the speech recognition system
func speechLog(_ level: SpeechLogger.LogLevel, component: SpeechLogger.Component, _ message: String) {
    SpeechLogger.shared.log(level, component: component, message)
}

func speechVerbose(_ message: String, component: SpeechLogger.Component) {
    SpeechLogger.shared.verbose(message, component: component)
}

func speechDebug(_ message: String, component: SpeechLogger.Component) {
    SpeechLogger.shared.debug(message, component: component)
}

func speechInfo(_ message: String, component: SpeechLogger.Component) {
    SpeechLogger.shared.info(message, component: component)
}

func speechWarning(_ message: String, component: SpeechLogger.Component) {
    SpeechLogger.shared.warning(message, component: component)
}

func speechError(_ message: String, component: SpeechLogger.Component, error: Error? = nil) {
    SpeechLogger.shared.error(message, component: component, error: error)
}
