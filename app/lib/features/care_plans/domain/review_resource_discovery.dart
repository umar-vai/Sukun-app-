import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/resource_matcher.dart';

/// Human-review suggestions only; never inserts links or approves plans.
class ReviewResourceDiscovery {
  const ReviewResourceDiscovery({
    required this.matches,
    this.missing = const [],
    this.note,
    this.requiresManualSelection = false,
  });

  final List<ResourceMatch> matches;
  final List<String> missing;
  final String? note;
  final bool requiresManualSelection;
}

ReviewResourceDiscovery discoverReviewResources({
  required String title,
  required String? instruction,
  required String? resourceMatchQuery,
  required List<ContentResourceOption> resources,
}) {
  // Include the instruction when an AI query only mentions one of the tracks.
  final source = '$title ${instruction ?? ''}'.toLowerCase();
  final matched = <ResourceMatch>[];
  final missing = <String>[];
  final visited = <String>{};
  var contextual = false;
  bool includesAny(List<String> terms) =>
      terms.any((term) => source.contains(term));

  void offer(String slug, String label, String type, {bool audio = false}) {
    final found = resources
        .where((resource) {
          if (!resource.isLinkable ||
              resource.slug != slug ||
              resource.type != type) {
            return false;
          }
          if (!audio) return true;
          final url = Uri.tryParse(resource.mediaUrl ?? '');
          return resource.mediaSourceType == 'direct_audio_url' &&
              url?.scheme == 'https' &&
              url?.host.isNotEmpty == true;
        })
        .toList(growable: false);
    if (found.length != 1) {
      missing.add(label);
    } else if (visited.add(found.single.id)) {
      matched.add(ResourceMatch(resource: found.single, score: 1));
    }
  }

  final jinn = includesAny([
    'জিনের আছর',
    'জিনের আসর',
    'জ্বিনের আছর',
    'jinn ruqyah',
    'jinn affliction',
  ]);
  final harq = includesAny(['হারক', 'হার্ক', 'harq']);
  final shifa = includesAny(['শিফা', 'shifa']);
  final sakina = includesAny(['সাকিনা', 'সাকীনা', 'সাকিনাহ', 'sakina']);
  final tadmir = includesAny(['তাদমির', 'তদমির', 'তাদমিল', 'তদমিল', 'tadmir']);
  final qital = includesAny(['কিতাল', 'qital']);
  if (jinn || harq || (shifa && sakina) || tadmir || qital) {
    contextual = true;
    if (jinn) {
      offer(
        'sukun-ruqyahbd-jinn',
        'জিনের আছরের রুকইয়াহ অডিও',
        'audio',
        audio: true,
      );
    }
    if (harq) {
      offer('sukun-ruqyahbd-harq', 'আয়াতুল হারক অডিও', 'audio', audio: true);
    }
    if (shifa && sakina) {
      offer(
        'sukun-ruqyahbd-shifa-sakina',
        'শিফা ও সাকিনা সম্মিলিত অডিও',
        'audio',
        audio: true,
      );
    }
    // No named audio for Tadmir/Qital in the approved published catalog.
    if (tadmir || qital) {
      missing.add('তাদমির/কিতাল: পৃথক যাচাইকৃত অডিও');
    }
  }

  // Individual published components; never claim a full Masnun packet.
  final masnun = includesAny(['মাসনুন', 'মাসনূন', 'masnun', 'masnoon']);
  final morning = includesAny(['সকাল', 'সন্ধ্যা', 'morning', 'evening']);
  final bedtime = includesAny([
    'ঘুম',
    'শোয়ার',
    'শোয়ার',
    'শোবার',
    'sleep',
    'bedtime',
  ]);
  if (masnun && (morning || bedtime)) {
    contextual = true;
    if (morning) {
      offer('srg2024-aml-002', 'সকাল–সন্ধ্যার তিন সূরার আমল', 'amal');
    }
    if (bedtime) {
      for (final item in [
        ('srg2024-aml-003', 'অজু করে ঘুমানোর আমল'),
        ('srg2024-aml-004', 'বিছানা ঝাড়ার আমল'),
        ('srg2024-aml-005', 'আয়াতুল কুরসির আমল'),
        ('srg2024-aml-006', 'সূরা বাকারার শেষ দুই আয়াতের আমল'),
        ('srg2024-aml-007', 'তিন কুলের আমল'),
      ]) {
        offer(item.$1, item.$2, 'amal');
      }
      offer('srg2024-dua-013', 'শোয়ার পরের দোয়া', 'dua');
    }
  }

  if (contextual) {
    return ReviewResourceDiscovery(
      matches: List.unmodifiable(matched),
      missing: List.unmodifiable(missing),
      note: masnun && (morning || bedtime)
          ? 'Related individual Dua/Amal cards only — NOT a verified '
                'complete Masnun routine. Compare each with the source.'
          : 'Named published audio tracks only. Confirm exact recording, '
                'listening sequence and instructions before linking.',
      requiresManualSelection: true,
    );
  }
  return ReviewResourceDiscovery(
    matches: matchResources(resourceMatchQuery ?? title, resources),
  );
}
