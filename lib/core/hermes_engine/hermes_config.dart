/// HermesEngine global configuration values.
/// Adjust these to change buffering behavior and thresholds.
library;

/// Number of seconds the audience sees the countdown
/// after a session starts or resumes.
const int kInitialCountdownSeconds = 8;

/// Minimum number of translated sentences that must be in the buffer
/// before countdown and playback can begin.
const int kMinBufferBeforeSpeaking = 3;

/// Minimum buffer to *resume* playback after a pause.
const int kResumeBufferThreshold = 2;

/// If speaker pauses and buffer is empty for this many seconds,
/// enter paused state and re-trigger countdown on resume.
const int kBufferDepletionTimeoutSeconds = 5;
