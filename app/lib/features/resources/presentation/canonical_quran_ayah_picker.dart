import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public Quran reader source, shared by routine and future admin selectors.
/// Only stable surah/ayah references are returned; verse text is never copied
/// into a routine or into a second CMS catalog.
class CanonicalQuranAyahChoice {
  const CanonicalQuranAyahChoice({
    required this.surahNumber,
    required this.ayahNumber,
  });

  final int surahNumber;
  final int ayahNumber;

  String get reference => 'quran:$surahNumber:$ayahNumber';
}

Future<CanonicalQuranAyahChoice?> showCanonicalQuranAyahPicker({
  required BuildContext context,
  Set<String> excludedReferences = const {},
}) => showModalBottomSheet<CanonicalQuranAyahChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) =>
      _CanonicalAyahPicker(excludedReferences: excludedReferences),
);

class _CanonicalAyahPicker extends StatefulWidget {
  const _CanonicalAyahPicker({required this.excludedReferences});

  final Set<String> excludedReferences;

  @override
  State<_CanonicalAyahPicker> createState() => _CanonicalAyahPickerState();
}

class _CanonicalAyahPickerState extends State<_CanonicalAyahPicker> {
  late final Future<List<Map<String, dynamic>>> _chapters = _loadChapters();
  final _verses = <Map<String, dynamic>>[];
  String _search = '';
  int? _selectedSurah;
  String _selectedTitle = '';
  int _page = 0;
  bool _more = false;
  bool _loading = false;
  String? _error;

  Future<List<Map<String, dynamic>>> _loadChapters() async {
    final response = await Supabase.instance.client.functions.invoke(
      'quran-content',
      body: {'action': 'chapters'},
    );
    final data = response.data;
    final raw = data is Map ? data['chapters'] : null;
    if (raw is! List) throw const FormatException('Quran catalog unavailable');
    final chapters = raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) {
          final id = row['id'];
          return id is int && id >= 1 && id <= 114;
        })
        .toList(growable: false);
    if (chapters.length != 114) {
      throw const FormatException('Canonical Quran chapters incomplete');
    }
    return chapters;
  }

  Future<void> _openSurah(int surah, String name) async {
    setState(() {
      _selectedSurah = surah;
      _selectedTitle = name;
      _page = 0;
      _more = true;
      _verses.clear();
      _error = null;
    });
    await _nextPage();
  }

  Future<void> _nextPage() async {
    final surah = _selectedSurah;
    if (surah == null || _loading || !_more) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'quran-content',
        body: {'action': 'verses', 'chapter': surah, 'page': _page + 1},
      );
      final data = response.data;
      if (data is! Map || data['verses'] is! List) {
        throw const FormatException('Quran verses unavailable');
      }
      final rows = (data['verses'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) {
            final key = row['verse_key']?.toString() ?? '';
            final parts = key.split(':');
            return parts.length == 2 &&
                int.tryParse(parts.first) == surah &&
                (int.tryParse(parts.last) ?? 0) > 0;
          })
          .toList(growable: false);
      final pagination = data['pagination'];
      final nextPage = pagination is Map ? pagination['next_page'] : null;
      if (!mounted || _selectedSurah != surah) return;
      setState(() {
        _verses.addAll(rows);
        _page++;
        _more = nextPage is num && nextPage > _page;
      });
    } catch (_) {
      if (mounted && _selectedSurah == surah) {
        setState(() => _error = 'আয়াত আনা যাচ্ছে না। আবার চেষ্টা করুন।');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                if (_selectedSurah != null)
                  IconButton(
                    tooltip: 'সূরার তালিকায় ফিরুন',
                    onPressed: () => setState(() {
                      _selectedSurah = null;
                      _search = '';
                    }),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedSurah == null
                            ? 'কুরআন → সূরা বাছুন'
                            : '$_selectedTitle → আয়াত বাছুন',
                        style: theme.textTheme.titleLarge,
                      ),
                      const Text(
                        'কুরআন রিডারের একই যাচাইকৃত API থেকে আয়াত দেখানো হচ্ছে।',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'বন্ধ করুন',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedSurah == null
                ? FutureBuilder<List<Map<String, dynamic>>>(
                    future: _chapters,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('সূরার তালিকা এখন পাওয়া যাচ্ছে না।'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final chapters = snapshot.data!
                          .where((row) {
                            final number = row['id'] as int;
                            final name = (row['name_simple'] ?? '')
                                .toString()
                                .toLowerCase();
                            return _search.isEmpty ||
                                name.contains(_search) ||
                                number.toString().contains(_search);
                          })
                          .toList(growable: false);
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded),
                                hintText: 'সূরার নাম বা নম্বর লিখুন',
                              ),
                              onChanged: (v) => setState(
                                () => _search = v.trim().toLowerCase(),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: chapters.length,
                              itemBuilder: (context, index) {
                                final chapter = chapters[index];
                                final number = chapter['id'] as int;
                                final name =
                                    chapter['name_simple']?.toString() ??
                                    'সূরা $number';
                                return ListTile(
                                  leading: CircleAvatar(child: Text('$number')),
                                  title: Text(name),
                                  subtitle: Text(
                                    '${chapter['verses_count'] ?? '—'} আয়াত',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openSurah(number, name),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : ListView(
                    children: [
                      for (final verse in _verses)
                        Builder(
                          builder: (context) {
                            final key = verse['verse_key']?.toString() ?? '';
                            final ayah = int.tryParse(key.split(':').last);
                            if (ayah == null) return const SizedBox.shrink();
                            final choice = CanonicalQuranAyahChoice(
                              surahNumber: _selectedSurah!,
                              ayahNumber: ayah,
                            );
                            final excluded = widget.excludedReferences.contains(
                              choice.reference,
                            );
                            final translated =
                                (verse['translations'] as List? ?? const [])
                                    .whereType<Map>()
                                    .where(
                                      (item) =>
                                          (item['language_name'] ?? '')
                                              .toString()
                                              .toLowerCase() ==
                                          'bengali',
                                    )
                                    .toList(growable: false);
                            final bangla = translated.isEmpty
                                ? null
                                : translated.first['text']?.toString();
                            return ListTile(
                              key: Key('canonical-ayah-$key'),
                              leading: CircleAvatar(child: Text('$ayah')),
                              title: Text(
                                verse['text_uthmani']?.toString() ?? key,
                                textDirection: TextDirection.rtl,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (bangla != null &&
                                      bangla.trim().isNotEmpty)
                                    Text(
                                      bangla,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    excluded
                                        ? 'ইতিমধ্যে রুটিনে আছে'
                                        : 'সূরা ${_selectedSurah!} · আয়াত $ayah',
                                  ),
                                ],
                              ),
                              enabled: !excluded,
                              onTap: excluded
                                  ? null
                                  : () => Navigator.pop(context, choice),
                            );
                          },
                        ),
                      if (_error != null)
                        ListTile(
                          title: Text(_error!),
                          trailing: TextButton(
                            onPressed: _nextPage,
                            child: const Text('আবার চেষ্টা'),
                          ),
                        ),
                      if (_more)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton(
                            onPressed: _loading ? null : _nextPage,
                            child: Text(
                              _loading ? 'আয়াত লোড হচ্ছে…' : 'আরও আয়াত দেখুন',
                            ),
                          ),
                        ),
                      if (_loading && _verses.isEmpty)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
