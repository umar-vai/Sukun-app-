import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Library cards are Sukun-owned UI. The existing, reviewed production
/// content_items retain their original provenance and review state.
class RuqyahSection {
  const RuqyahSection(this.title, this.subtitle, this.audioSlug);

  final String title;
  final String subtitle;
  // A verified, existing *section recording*, never described as an
  // individual verse recording or a verbatim match to one excerpt.
  final String? audioSlug;
}

const ruqyahSections = <RuqyahSection>[
  RuqyahSection(
    'বেসিক রুকইয়াহ',
    'প্রাথমিক রুকইয়াহর নির্বাচিত আয়াত',
    'sukun-ruqyahbd-common-bangla',
  ),
  RuqyahSection(
    'রুকইয়াহ আয়াত',
    'বিষয়ভিত্তিক রুকইয়াহর আয়াত ও অংশ',
    'sukun-ruqyahbd-eight-surah',
  ),
  RuqyahSection('রুকইয়াহ দোয়া', 'নির্বাচিত দোয়া ও বাংলা অর্থ', null),
  RuqyahSection(
    'বদনজরের আয়াত',
    'বদনজর সম্পর্কিত নির্বাচিত আয়াত',
    'sukun-ruqyahbd-evil-eye',
  ),
  RuqyahSection(
    'সিহরের আয়াত',
    'জাদু ও সিহর সম্পর্কিত আয়াত',
    'sukun-ruqyahbd-sihr-hibshi',
  ),
  RuqyahSection('আয়াতুশ শিফা', 'শিফা সম্পর্কিত আয়াত', 'sukun-ruqyahbd-shifa'),
  RuqyahSection(
    'আয়াতুল হারক',
    'হারক সম্পর্কিত নির্বাচিত আয়াত',
    'sukun-ruqyahbd-harq',
  ),
  RuqyahSection(
    'আয়াতুস সাকিনাহ',
    'সাকিনাহ সম্পর্কিত আয়াত',
    'sukun-ruqyahbd-shifa-sakina',
  ),
];

/// Explicitly maps already-reviewed book excerpt identifiers. No guessed
/// surah/ayah boundaries and no attribution to a different source corpus.
int? ruqyahSectionForSlug(String slug) {
  if (slug.startsWith('srg2024-dua-')) return 2;
  if (!RegExp(r'^srg2024-qur-[0-9]{3}$').hasMatch(slug)) return null;
  final number = int.tryParse(slug.substring(slug.length - 3));
  if (number == null || number < 1 || number > 101) return null;
  if (number <= 13) return 0;
  if (number <= 19) return 1;
  if (number <= 27) return 6;
  if (number <= 37) return 3;
  if (number <= 48) return 4;
  if (number <= 54) return 5;
  if (number <= 84) return 1;
  if (number <= 90) return 7;
  return 1;
}

/// Bengali names of surahs referenced in the approved editorial mapping.
/// An unknown surah does not get a made-up title.
const ruqyahSurahNamesBn = <int, String>{
  1: 'আল-ফাতিহা',
  2: 'আল-বাকারা',
  3: 'আলে ইমরান',
  4: 'আন-নিসা',
  5: 'আল-মায়িদা',
  6: 'আল-আনআম',
  7: 'আল-আরাফ',
  8: 'আল-আনফাল',
  9: 'আত-তাওবা',
  10: 'ইউনুস',
  12: 'ইউসুফ',
  13: 'আর-রাদ',
  14: 'ইবরাহিম',
  15: 'আল-হিজর',
  16: 'আন-নাহল',
  17: 'আল-ইসরা',
  19: 'মারইয়াম',
  20: 'ত্ব-হা',
  21: 'আল-আম্বিয়া',
  23: 'আল-মুমিনুন',
  25: 'আল-ফুরকান',
  26: 'আশ-শুআরা',
  27: 'আন-নামল',
  29: 'আল-আনকাবুত',
  36: 'ইয়াসিন',
  37: 'আস-সাফফাত',
  39: 'আয-যুমার',
  41: 'ফুসসিলাত',
  48: 'আল-ফাতহ',
  55: 'আর-রহমান',
  59: 'আল-হাশর',
  65: 'আত-তালাক',
  71: 'নূহ',
  72: 'আল-জিন',
  76: 'আল-ইনসান',
  84: 'আল-ইনশিকাক',
  86: 'আত-তারিক',
  97: 'আল-কদর',
  99: 'আয-যিলযাল',
  112: 'আল-ইখলাস',
  113: 'আল-ফালাক',
  114: 'আন-নাস',
};

String ruqyahBanglaNumber(int number) {
  const digits = '০১২৩৪৫৬৭৮৯';
  return number.toString().split('').map((value) {
    final digit = int.tryParse(value);
    return digit == null ? value : digits[digit];
  }).join();
}

/// The source book's "আয়াত/অংশ 13" is NOT a Quran ayah number.
String ruqyahDisplayTitle(String title) =>
    title.replaceFirst(RegExp(r'\s*—\s*আয়াত/অংশ\s*[0-9০-৯]+\s*$'), '').trim();

/// A source-book start reference never establishes the end of the excerpt.
String? ruqyahCitation({
  required int? surahNumber,
  required int? ayahNumber,
  int? ayahEndNumber,
}) {
  if (surahNumber == null ||
      ayahNumber == null ||
      surahNumber < 1 ||
      surahNumber > 114 ||
      ayahNumber < 1) {
    return null;
  }
  final surah = ruqyahSurahNamesBn[surahNumber];
  if (surah == null) return null;
  final start = ruqyahBanglaNumber(ayahNumber);
  if (ayahEndNumber != null && ayahEndNumber >= ayahNumber) {
    final end = ruqyahBanglaNumber(ayahEndNumber);
    final suffix = ayahEndNumber == ayahNumber ? '' : '–$end';
    return 'সূরা $surah · আয়াত $start$suffix';
  }
  return 'সূরা $surah · আয়াত $start থেকে নির্বাচিত পাঠ';
}

class _FirstAyahBangla {
  const _FirstAyahBangla(this.translation, this.edition, this.provider);

  final String translation;
  final String edition;
  final String provider;
}

class _RuqyahEntry {
  const _RuqyahEntry(this.json);

  final Map<String, dynamic> json;

  String get slug => json['slug'] as String? ?? '';
  String get title => (json['title_bn'] as String?)?.trim().isNotEmpty == true
      ? json['title_bn'] as String
      : json['title'] as String? ?? 'দোয়া ও আয়াত';
  String get arabic => json['arabic_text'] as String? ?? '';
  String get displayTitle => ruqyahDisplayTitle(title);

  int? get surahNumber => json['surah_number'] as int?;
  int? get ayahNumber => json['ayah_number'] as int?;
  int? get ayahEndNumber => json['ayah_end_number'] as int?;
  String? get citation => ruqyahCitation(
    surahNumber: surahNumber,
    ayahNumber: ayahNumber,
    ayahEndNumber: ayahEndNumber,
  );
  String get meaning {
    for (final key in ['bangla_text', 'translation']) {
      final value = json[key] as String?;
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return '';
  }
}

class _RuqyahLibraryData {
  const _RuqyahLibraryData(this.entries, this.sectionAudio);

  final List<_RuqyahEntry> entries;
  final Map<String, String> sectionAudio;
}

class RuqyahAyatLibrary extends StatefulWidget {
  const RuqyahAyatLibrary({super.key});

  @override
  State<RuqyahAyatLibrary> createState() => _RuqyahAyatLibraryState();
}

class _RuqyahAyatLibraryState extends State<RuqyahAyatLibrary> {
  late Future<_RuqyahLibraryData> _future = _load();

  Future<_RuqyahLibraryData> _load() async {
    final client = Supabase.instance.client;
    // Published/RLS-visible only. Do not pull drafts or staff-only resources.
    final results = await Future.wait([
      client
          .from('content_items')
          .select(
            'slug,title,title_bn,arabic_text,bangla_text,translation,surah_number,ayah_number,ayah_end_number',
          )
          .eq('status', 'published')
          .like('slug', 'srg2024-qur-%')
          .order('slug'),
      client
          .from('content_items')
          .select(
            'slug,title,title_bn,arabic_text,bangla_text,translation,surah_number,ayah_number,ayah_end_number',
          )
          .eq('status', 'published')
          .like('slug', 'srg2024-dua-%')
          .order('slug'),
      client
          .from('content_items')
          .select('slug,media_url')
          .eq('status', 'published')
          .inFilter('slug', [
            for (final section in ruqyahSections)
              if (section.audioSlug != null) section.audioSlug!,
          ]),
    ]);
    final entries = <_RuqyahEntry>[];
    for (final record in [...results[0], ...results[1]]) {
      final entry = _RuqyahEntry(Map<String, dynamic>.from(record));
      if (ruqyahSectionForSlug(entry.slug) != null &&
          entry.arabic.trim().isNotEmpty) {
        entries.add(entry);
      }
    }
    final audio = <String, String>{};
    for (final row in results[2]) {
      final slug = row['slug'] as String?;
      final url = row['media_url'] as String?;
      final parsed = Uri.tryParse(url ?? '');
      if (slug != null &&
          parsed?.scheme == 'https' &&
          parsed?.host == 'files.ruqyahbd.org') {
        audio[slug] = url!;
      }
    }
    return _RuqyahLibraryData(entries, audio);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RuqyahLibraryData>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('রুকইয়াহ পাঠ লোড করা যাচ্ছে না।'),
                TextButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('আবার চেষ্টা করুন'),
                ),
              ],
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final groups = List.generate(
        ruqyahSections.length,
        (section) => data.entries
            .where((entry) => ruqyahSectionForSlug(entry.slug) == section)
            .toList(growable: false),
      );
      return LayoutBuilder(
        builder: (context, bounds) {
          final columns = bounds.maxWidth >= 740 ? 2 : 1;
          final width = bounds.maxWidth > 1000 ? 1000.0 : bounds.maxWidth;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'রুকইয়াহ আয়াত',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'নির্বাচিত রুকইয়াহ আয়াত ও দোয়ার সংকলন',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 26),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ruqyahSections.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 110,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final section = ruqyahSections[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _RuqyahSectionReader(
                                    data: data,
                                    groups: groups,
                                    initialSection: index,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(child: Text('${index + 1}')),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            section.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${section.subtitle} · ${groups[index].length}টি',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'পাঠ ও অডিও যাচাইকৃত তথ্যের ভিত্তিতে দেখানো হয়। প্রতিটি বিভাগের অডিও আলাদা রেকর্ডিং।',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _RuqyahSectionReader extends StatefulWidget {
  const _RuqyahSectionReader({
    required this.data,
    required this.groups,
    required this.initialSection,
  });

  final _RuqyahLibraryData data;
  final List<List<_RuqyahEntry>> groups;
  final int initialSection;

  @override
  State<_RuqyahSectionReader> createState() => _RuqyahSectionReaderState();
}

class _RuqyahSectionReaderState extends State<_RuqyahSectionReader> {
  late int _section = widget.initialSection;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _favorites = {};
  String? _playingSlug;
  bool _loadingAudio = false;
  final Set<String> _expandedMeanings = {};
  final Map<String, Future<_FirstAyahBangla?>> _banglaRequests = {};

  /// Fetch only the explicitly cited start verse; source-book paragraphs can
  /// contain more verses, and their end boundaries are not reviewed.
  Future<_FirstAyahBangla?> _fetchFirstAyahBangla(_RuqyahEntry entry) async {
    final surah = entry.surahNumber;
    final ayah = entry.ayahNumber;
    if (surah == null || ayah == null || entry.citation == null) {
      return null;
    }
    final page = ((ayah - 1) ~/ 50) + 1;
    final response = await Supabase.instance.client.functions.invoke(
      'quran-content',
      body: {'action': 'verses', 'chapter': surah, 'page': page},
    );
    final data = response.data;
    if (data is! Map) return null;
    final verses = data['verses'];
    if (verses is! List) return null;
    for (final raw in verses) {
      if (raw is! Map || raw['verse_key'] != '$surah:$ayah') continue;
      final translations = raw['translations'];
      if (translations is! List) return null;
      for (final item in translations) {
        if (item is! Map) continue;
        if (item['language_name']?.toString().toLowerCase() != 'bengali') {
          continue;
        }
        final translation = item['text']?.toString().trim() ?? '';
        if (translation.isEmpty) return null;
        final edition = item['resource_name']?.toString().trim();
        return _FirstAyahBangla(
          translation,
          (edition?.isNotEmpty ?? false)
              ? edition!
              : data['translation_name']?.toString() ?? 'বাংলা অনুবাদ',
          data['provider']?.toString() ?? 'Quran Foundation',
        );
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_readFavorites());
  }

  Future<void> _readFavorites() async {
    final store = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _favorites.addAll(
        store.getStringList('sukun.ruqyah.favorites') ?? const [],
      ),
    );
  }

  Future<void> _toggleFavorite(String slug) async {
    setState(() {
      if (!_favorites.add(slug)) _favorites.remove(slug);
    });
    final store = await SharedPreferences.getInstance();
    await store.setStringList('sukun.ruqyah.favorites', _favorites.toList());
  }

  Future<void> _playSection() async {
    final slug = ruqyahSections[_section].audioSlug;
    final url = widget.data.sectionAudio[slug];
    if (slug == null || url == null || _loadingAudio) return;
    try {
      if (_playingSlug == slug) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          unawaited(_audioPlayer.play());
        }
      } else {
        setState(() => _loadingAudio = true);
        await _audioPlayer.setUrl(url);
        if (!mounted) return;
        _playingSlug = slug;
        unawaited(_audioPlayer.play());
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('অডিও চালু হয়নি। ইন্টারনেট সংযোগ পরীক্ষা করুন।'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _changeSection(int index) async {
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _section = index;
      _playingSlug = null;
      _expandedMeanings.clear();
    });
  }

  @override
  void dispose() {
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = ruqyahSections[_section];
    final entries = widget.groups[_section];
    final hasAudio = widget.data.sectionAudio.containsKey(section.audioSlug);
    final showSidebar = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(title: const Text('রুকইয়াহ আয়াত')),
      body: Row(
        children: [
          if (showSidebar)
            SizedBox(
              width: 250,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text('আয়াত বিভাগসমূহ'),
                  const SizedBox(height: 12),
                  for (var i = 0; i < ruqyahSections.length; i++)
                    ListTile(
                      selected: i == _section,
                      dense: true,
                      leading: Text('${i + 1}'),
                      title: Text(ruqyahSections[i].title),
                      onTap: () => _changeSection(i),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!showSidebar)
                  DropdownButtonFormField<int>(
                    initialValue: _section,
                    decoration: const InputDecoration(
                      labelText: 'আয়াত বিভাগ',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < ruqyahSections.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(ruqyahSections[i].title),
                        ),
                    ],
                    onChanged: (i) {
                      if (i != null) unawaited(_changeSection(i));
                    },
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        Text('${section.subtitle} · ${entries.length}টি পাঠ'),
                        if (hasAudio) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loadingAudio ? null : _playSection,
                            icon: Icon(
                              _playingSlug == section.audioSlug &&
                                      _audioPlayer.playing
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                            ),
                            label: Text(
                              _playingSlug == section.audioSlug &&
                                      _audioPlayer.playing
                                  ? 'বিভাগের অডিও থামান'
                                  : 'বিভাগের অডিও শুনুন',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('এই বিভাগে যাচাইকৃত পাঠ এখনও যোগ করা হয়নি।'),
                  ),
                for (var i = 0; i < entries.length; i++) ...[
                  _entryCard(context, entries[i]),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(BuildContext context, _RuqyahEntry item) {
    final meaning = item.meaning;
    final expanded = _expandedMeanings.contains(item.slug);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'ফেভারিট',
                  icon: Icon(
                    _favorites.contains(item.slug)
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  onPressed: () => _toggleFavorite(item.slug),
                ),
                IconButton(
                  tooltip: 'কপি',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: item.arabic));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('আরবি পাঠ কপি হয়েছে')),
                      );
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            Directionality(
              textDirection: TextDirection.rtl,
              child: SelectableText(
                item.arabic,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 27, height: 2.1),
              ),
            ),
            const SizedBox(height: 12),
            if (item.citation != null)
              Text(
                item.citation!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const Divider(),
            TextButton.icon(
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                expanded ? 'বাংলা অর্থ বন্ধ করুন' : 'বাংলা অর্থ দেখুন',
              ),
              onPressed: () => setState(() {
                if (!_expandedMeanings.add(item.slug)) {
                  _expandedMeanings.remove(item.slug);
                }
              }),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.all(12),
                child: meaning.isNotEmpty
                    ? Text(meaning)
                    : item.citation == null
                    ? const Text(
                        'এই পাঠের যাচাইকৃত বাংলা অর্থ এখনো যুক্ত হয়নি।',
                      )
                    : FutureBuilder<_FirstAyahBangla?>(
                        future: _banglaRequests.putIfAbsent(
                          item.slug,
                          () => _fetchFirstAyahBangla(item),
                        ),
                        builder: (context, snapshot) {
                          final result = snapshot.data;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (snapshot.connectionState !=
                                  ConnectionState.done)
                                const LinearProgressIndicator()
                              else if (result == null) ...[
                                const Text(
                                  'এই সূত্রের বাংলা অনুবাদ এখন পাওয়া যাচ্ছে না।',
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    _banglaRequests.remove(item.slug);
                                  }),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('আবার চেষ্টা করুন'),
                                ),
                              ] else ...[
                                Text(
                                  'উল্লেখিত শুরুর আয়াতের বাংলা অর্থ',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                SelectableText(result.translation),
                                const SizedBox(height: 8),
                                Text(
                                  'অনুবাদ: ${result.edition} · উৎস: ${result.provider}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'এটি শুধু সূত্রে উল্লেখিত শুরুর আয়াতের অনুবাদ। '
                                  'এই পাঠে আরও আয়াত থাকলে সেগুলোর পূর্ণ বাংলা '
                                  'অনুবাদ এখানে যাচাই করা হয়নি।',
                                ),
                              ],
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => context.push(
                                  '/resources/quran/${item.surahNumber}',
                                ),
                                icon: const Icon(Icons.menu_book_outlined),
                                label: const Text(
                                  'সম্পূর্ণ সূরা বাংলা অর্থসহ পড়ুন',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
