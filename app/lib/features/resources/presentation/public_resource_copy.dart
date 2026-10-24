/// Presentation-only cleanup for published resource instructions. Original
/// source, verification and rights records remain in Admin CMS and Supabase.
/// Do not run this on canonical Arabic, translations or Quran/Hadith identifiers.
String? publicResourceInstructions(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final metadata = RegExp(
    r'owner-provided source|editorial review|review required|before publishing|'
    r'internal (?:note|metadata|review)|source reference|source edition|'
    r'publication rights|rights note|licensing status|'
    r'paragraph\s*[0-9০-৯]+|'
    r'সূত্র যাচাই প্রয়োজন|রেফারেন্স মিলেছে|সম্পাদনাগত নোট',
    caseSensitive: false,
  );
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .where((line) => !metadata.hasMatch(line))
      .join('\n')
      .trim();
  return lines.isEmpty ? null : lines;
}
