/// Returns a human-friendly language name for a given BCP-47 language code.
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
      return code; // fallback
  }
}

/// Converts a country or locale code to an emoji flag.
/// Example: 'us', 'en-US' → 🇺🇸
String emojiFlagFromCode(String code) {
  final countryCode = code.contains('-') ? code.split('-').last : code;
  if (countryCode.length != 2) return '';
  final base = countryCode.toUpperCase().codeUnits;
  return String.fromCharCode(base[0] + 127397) +
      String.fromCharCode(base[1] + 127397);
}

/// Combines flag and language for UI display.
String labeledLanguage(String code) {
  final flag = emojiFlagFromCode(code);
  final name = languageNameFromCode(code);
  return '$flag $name';
}
