/// A FIFO buffer for managing translated text segments before they are spoken.
class TranslationBuffer {
  final List<String> _queue = [];

  /// Adds a new translated sentence to the buffer.
  void add(String sentence) {
    if (sentence.trim().isNotEmpty) {
      _queue.add(sentence.trim());
    }
  }

  /// Returns the next sentence in the buffer and removes it from the queue.
  String? pop() {
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }

  /// Peeks at the next sentence without removing it.
  String? peek() {
    return _queue.isEmpty ? null : _queue.first;
  }

  /// Returns the current buffer contents (immutable copy).
  List<String> get all => List.unmodifiable(_queue);

  /// Clears all buffer content.
  void clear() => _queue.clear();

  /// True if the buffer has no content.
  bool get isEmpty => _queue.isEmpty;

  /// True if the buffer has at least one sentence.
  bool get isNotEmpty => _queue.isNotEmpty;

  /// Returns the number of sentences in the buffer.
  int get length => _queue.length;
}
