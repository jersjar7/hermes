/// Represents an internal event that drives the HermesEngine state machine.
sealed class HermesEvent {
  const HermesEvent();
}

/// Emitted when a final speech result is received from STT.
class SpeechFinalized extends HermesEvent {
  final String transcript;
  const SpeechFinalized(this.transcript);
}

/// Emitted when a translated string is returned from the translator.
class TranslationCompleted extends HermesEvent {
  final String translatedText;
  const TranslationCompleted(this.translatedText);
}

/// Emitted when the buffer reaches the threshold to start speaking.
class BufferReady extends HermesEvent {
  const BufferReady();
}

/// Emitted when playback of a sentence has finished.
class PlaybackFinished extends HermesEvent {
  const PlaybackFinished();
}

/// Emitted when the buffer is empty and the engine should pause.
class BufferEmpty extends HermesEvent {
  const BufferEmpty();
}

/// Emitted when the countdown timer completes.
class CountdownFinished extends HermesEvent {
  const CountdownFinished();
}

/// Emitted when a recoverable error occurs.
class EngineErrorOccurred extends HermesEvent {
  final String message;
  const EngineErrorOccurred(this.message);
}
