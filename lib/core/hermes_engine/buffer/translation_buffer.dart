// lib/core/hermes_engine/buffer/translation_buffer.dart

/// FIFO buffer for managing translated text segments before they are spoken.
class TranslationBuffer {
  final List<String> _queue = [];

  /// Adds a translated sentence to the buffer if non-empty.
  void add(String sentence) {
    final trimmed = sentence.trim();
    if (trimmed.isNotEmpty) {
      _queue.add(trimmed);
    }
  }

  /// Retrieves and removes the next sentence from the buffer.
  /// Returns null if the buffer is empty.
  String? pop() {
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }

  /// Peeks at the next sentence without removing it.
  String? peek() => _queue.isEmpty ? null : _queue.first;

  /// Clears all buffered content.
  void clear() => _queue.clear();

  /// Returns an immutable copy of the current buffer.
  List<String> get all => List.unmodifiable(_queue);

  /// Whether the buffer has at least one segment.
  bool get isNotEmpty => _queue.isNotEmpty;

  /// Whether the buffer is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Number of segments currently buffered.
  int get length => _queue.length;
}
