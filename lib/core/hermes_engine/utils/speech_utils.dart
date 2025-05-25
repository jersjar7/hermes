// lib/core/hermes_engine/utils/speech_utils.dart

/// Cleans up raw speech-to-text transcripts for better translation and TTS.
library;

/// Trims whitespace, capitalizes first letter, and ensures ending punctuation.
String cleanTranscript(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  // Capitalize first letter
  final capitalized = trimmed[0].toUpperCase() + trimmed.substring(1);

  // Add punctuation if missing
  if (RegExp(r'[.?!]$').hasMatch(capitalized)) {
    return capitalized;
  } else {
    return '$capitalized.';
  }
}

/// Attempts to split transcript into logical sentence-like pieces.
/// Not always accurate, but helpful for long dictations.
List<String> splitIntoSentences(String input) {
  final rawSentences = input.split(RegExp(r'[.?!]\s+'));
  return rawSentences
      .map((s) => cleanTranscript(s))
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Checks if a given text likely represents a complete sentence.
bool isLikelyFinalSentence(String text) {
  final trimmed = text.trim();
  return RegExp(r'[.?!]$').hasMatch(trimmed);
}
