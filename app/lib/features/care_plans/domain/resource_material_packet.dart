import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Read-only material packet from reviewer-provided instructions and approved
/// resource text; never an automated publication or new religious source.
class ResourceMaterialPacket {
  ResourceMaterialPacket._();

  static String draftMarkdown(List<MaterialPacketAction> actions) {
    if (actions.isEmpty) {
      throw ArgumentError('At least one action must be selected.');
    }
    final buffer = StringBuffer()
      ..writeln('# সুকুন লাইফ — উপকরণের খসড়া')
      ..writeln()
      ..writeln('**শুধু অ্যাডমিন পর্যালোচনার জন্য — রোগীর জন্য প্রকাশিত নয়।**')
      ..writeln(
        'নিচের নিয়মগুলো মূল প্রেসক্রিপশন ও অনুমোদিত উৎসের সঙ্গে মিলিয়ে দেখুন।',
      )
      ..writeln();

    for (var index = 0; index < actions.length; index++) {
      final action = actions[index];
      final name = action.title.trim();
      if (name.isEmpty) throw ArgumentError('Every action needs a title.');
      buffer
        ..writeln('## ${index + 1}. $name')
        ..writeln()
        ..writeln('- [ ] কাজ সম্পন্ন')
        ..writeln();
      final instruction = action.instruction?.trim();
      if (instruction != null && instruction.isNotEmpty) {
        buffer
          ..writeln('**মূল প্রেসক্রিপশনের নির্দেশনা:** $instruction')
          ..writeln();
      }
      if (action.countTarget != null && action.countTarget! > 0) {
        buffer
          ..writeln('**প্রেসক্রিপশনে উল্লেখিত সংখ্যা:** ${action.countTarget}')
          ..writeln();
      }
      if (action.durationMinutes != null && action.durationMinutes! > 0) {
        buffer
          ..writeln(
            '**প্রেসক্রিপশনে উল্লেখিত সময়:** ${action.durationMinutes} মিনিট',
          )
          ..writeln();
      }

      final resource = action.resource;
      final approved =
          resource != null &&
          resource.status == 'published' &&
          const {
            'public',
            'patient_only',
            'assigned_only',
          }.contains(resource.visibility) &&
          (!const {'quran', 'hadith'}.contains(resource.type) ||
              resource.verificationStatus == 'verified');

      if (!approved) {
        buffer
          ..writeln(
            '**উপকরণের অবস্থা:** অনুমোদিত উৎস পাওয়া যায়নি; '
            'অ্যাডমিন যাচাই ও Resource Library linkage প্রয়োজন।',
          )
          ..writeln();
        continue;
      }
      final displayTitle = resource.titleBn?.trim().isNotEmpty == true
          ? resource.titleBn!.trim()
          : resource.title;
      buffer
        ..writeln('**অনুমোদিত উপকরণ:** $displayTitle')
        ..writeln();
      for (final field in [
        ('আরবি', resource.arabicText),
        ('বাংলা', resource.banglaText),
        ('অর্থ/অনুবাদ', resource.translation),
        ('বিস্তারিত', resource.body),
        ('উৎস', resource.referenceText ?? resource.sourceReference),
      ]) {
        final value = field.$2?.trim();
        if (value == null || value.isEmpty) continue;
        buffer
          ..writeln('**${field.$1}:**')
          ..writeln()
          ..writeln(value)
          ..writeln();
      }
      final media = resource.mediaUrl?.trim();
      if (media != null && media.isNotEmpty && media.startsWith('https://')) {
        buffer
          ..writeln('**অডিও/পিডিএফ লিংক:** $media')
          ..writeln();
      }
    }
    buffer
      ..writeln('---')
      ..writeln(
        '**প্রকাশের আগে:** আরবি পাঠ, সূত্র, অনুবাদ, সংখ্যা, সময়, '
        'নির্দেশনা ও রোগীর জন্য উপযোগিতা Admin যাচাই করবেন।',
      );
    return buffer.toString();
  }
}

class MaterialPacketAction {
  const MaterialPacketAction({
    required this.title,
    this.instruction,
    this.countTarget,
    this.durationMinutes,
    this.resource,
  });

  final String title;
  final String? instruction;
  final int? countTarget;
  final int? durationMinutes;
  final ContentResource? resource;
}
