// lib/core/hermes_engine/config/hermes_config.dart

/// HermesEngine configuration constants
library;

/// Number of seconds to buffer before starting playback.
const int kInitialBufferCountdownSeconds = 8;

/// Minimum number of translated segments required before playback begins.
const int kMinBufferSegments = 2;

/// Minimum number of buffered segments to resume playback after a pause.
const int kResumeBufferThreshold = 1;

/// After buffer depletes, how many seconds before entering paused state.
const int kBufferDepletionTimeoutSeconds = 5;

/// No trailing slash!
/// Override at build time with --dart-define=HERMES_WS_URL=...
const String kWebSocketBaseUrl = String.fromEnvironment(
  'HERMES_WS_URL',
  defaultValue: 'ws://localhost:8080',
);
