// lib/core/hermes_engine/state/hermes_event.dart

/// Defines internal events for driving the HermesEngine state machine.
sealed class HermesEvent {
  const HermesEvent();
}

/// Fired when a final speech result is ready for translation.
class SpeechFinalized extends HermesEvent {
  final String transcript;
  const SpeechFinalized(this.transcript);
}

/// Fired when the translation of a transcript completes.
class TranslationCompleted extends HermesEvent {
  final String translatedText;
  const TranslationCompleted(this.translatedText);
}

/// Fired when the buffer has enough segments to start playback.
class BufferReady extends HermesEvent {
  const BufferReady();
}

/// Fired when playback of one segment finishes.
class PlaybackFinished extends HermesEvent {
  const PlaybackFinished();
}

/// Fired when the buffer becomes empty during playback.
class BufferEmpty extends HermesEvent {
  const BufferEmpty();
}

/// Fired when the countdown timer completes.
class CountdownFinished extends HermesEvent {
  const CountdownFinished();
}

/// Fired when any recoverable error occurs in the engine.
class EngineErrorOccurred extends HermesEvent {
  final String message;
  const EngineErrorOccurred(this.message);
}
