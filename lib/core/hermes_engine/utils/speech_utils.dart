/// Cleans up raw STT output before translation.
String cleanTranscript(String raw) {
  final trimmed = raw.trim();

  if (trimmed.isEmpty) return '';

  // Capitalize first letter
  final capitalized = trimmed[0].toUpperCase() + trimmed.substring(1);

  // Add punctuation if not present
  final punctuated =
      capitalized.endsWith('.') ||
              capitalized.endsWith('!') ||
              capitalized.endsWith('?')
          ? capitalized
          : '$capitalized.';

  return punctuated;
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

/// Rudimentary check to see if a sentence seems finished.
bool isLikelyFinalSentence(String text) {
  final trimmed = text.trim();
  return RegExp(r'[.?!]$').hasMatch(trimmed);
}
