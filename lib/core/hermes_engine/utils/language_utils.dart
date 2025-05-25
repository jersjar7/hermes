// lib/core/hermes_engine/utils/language_utils.dart

/// Maps BCP-47 language codes to human-friendly names and optional flags.
library;

/// Returns a human-readable name for a given language code.
String languageNameFromCode(String code) {
  final base = code.split('-').first.toLowerCase();
  switch (base) {
    case 'en':
      return 'English';
    case 'es':
      return 'Spanish';
    case 'fr':
      return 'French';
    case 'de':
      return 'German';
    case 'zh':
      return 'Chinese';
    case 'ar':
      return 'Arabic';
    case 'hi':
      return 'Hindi';
    case 'ru':
      return 'Russian';
    case 'pt':
      return 'Portuguese';
    case 'ja':
      return 'Japanese';
    case 'it':
      return 'Italian';
    case 'ko':
      return 'Korean';
    default:
      return code; // Fallback to code itself
  }
}

/// Converts a country or locale code to its emoji flag representation.
String emojiFlagFromCode(String code) {
  final country = code.contains('-') ? code.split('-').last : code;
  if (country.length != 2) return '';
  final int flagOffset = 0x1F1E6;
  final int asciiOffset = 0x41;
  final chars = country.toUpperCase().codeUnits;
  return String.fromCharCode(flagOffset + (chars[0] - asciiOffset)) +
      String.fromCharCode(flagOffset + (chars[1] - asciiOffset));
}

/// Returns a combined label (flag + name), e.g. "🇪🇸 Spanish".
String labeledLanguage(String code) {
  final flag = emojiFlagFromCode(code);
  final name = languageNameFromCode(code);
  return flag.isNotEmpty ? '$flag $name' : name;
}
