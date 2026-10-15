import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _navy = Color(0xFF0D2B45);
const _blue = Color(0xFF0F9BD7);
const _border = Color(0xFFDCE8EF);

/// This rights-authorized collection is bundled in the real Flutter app.
/// The 105 source entries are copied verbatim in an auditable data asset.
/// No third-party navigation, attribution advertisement, or site UI is shown.
class RuqyahCollection {
  const RuqyahCollection(this.groups, this.entries);
  final List<RuqyahGroup> groups;
  final List<RuqyahEntry> entries;

  static Future<RuqyahCollection> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/ruqyah_ayat_authorized.json',
    );
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final groups = (data['groups'] as List)
        .map((x) => RuqyahGroup.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(growable: false);
    final entries = (data['entries'] as List)
        .map((x) => RuqyahEntry.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(growable: false);
    if (groups.length != 8 ||
        entries.length != 105 ||
        groups.map((x) => x.id).toSet().length != 8 ||
        entries.map((x) => x.id).toSet().length != 105 ||
        entries.any(
          (e) => e.arabic.trim().isEmpty || e.bangla.trim().isEmpty,
        )) {
      throw const FormatException(
        'Ruqyah source integrity verification failed',
      );
    }
    return RuqyahCollection(groups, entries);
  }
}

class RuqyahGroup {
  const RuqyahGroup(this.id, this.title, this.subtitle);
  final int id;
  final String title;
  final String subtitle;

  factory RuqyahGroup.fromJson(Map<String, dynamic> x) => RuqyahGroup(
    x['id'] as int,
    x['title'] as String,
    x['subtitle'] as String,
  );
}

class RuqyahEntry {
  const RuqyahEntry(
    this.id,
    this.groupId,
    this.number,
    this.title,
    this.arabic,
    this.bangla,
    this.note,
    this.audioPath,
  );

  final int id;
  final int groupId;
  final int number;
  final String title;
  final String arabic;
  final String bangla;
  final String? note;
  final String? audioPath;

  factory RuqyahEntry.fromJson(Map<String, dynamic> x) => RuqyahEntry(
    x['id'] as int,
    x['group_id'] as int,
    x['ayah_number'] as int,
    x['ayah_title'] as String? ?? '',
    (x['ayah_arabic'] as String? ?? '').replaceAll('&nbsp;', ' ').trim(),
    (x['ayah_bangla'] as String? ?? '').replaceAll('&nbsp;', ' ').trim(),
    x['ayah_note'] as String?,
    x['audiopath']?.toString(),
  );

  /// The source asset contains an audio ID, never an arbitrary executable URL.
  /// Render the audio inside Sukun's player without redirecting to another site.
  String? get audioUrl {
    final value = audioPath;
    if (value == null ||
        value == '0' ||
        !RegExp(r'^[0-9]+_[0-9]+$').hasMatch(value)) {
      return null;
    }
    return 'https://files.ruqyahbd.org/appfiles/ruqyah-ayat/$value.mp3';
  }
}

class RuqyahAyatCollectionScreen extends StatefulWidget {
  const RuqyahAyatCollectionScreen({super.key});

  @override
  State<RuqyahAyatCollectionScreen> createState() =>
      _RuqyahAyatCollectionScreenState();
}

class _RuqyahAyatCollectionScreenState
    extends State<RuqyahAyatCollectionScreen> {
  late Future<RuqyahCollection> _future;

  @override
  void initState() {
    super.initState();
    _future = RuqyahCollection.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RuqyahCollection>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('রুকইয়াহ আয়াতের তথ্য পড়া যাচ্ছে না।'),
              TextButton(
                onPressed: () =>
                    setState(() => _future = RuqyahCollection.load()),
                child: const Text('আবার চেষ্টা করুন'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final catalog = snapshot.requireData;
      return LayoutBuilder(
        builder: (context, limits) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                children: [
                  const Icon(Icons.menu_book_rounded, size: 48, color: _blue),
                  const SizedBox(height: 10),
                  Text(
                    'রুকইয়াহ আয়াত',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: _navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text('প্রয়োজনীয় রুকইয়াহ আয়াত ও দোয়ার সংকলন'),
                  const SizedBox(height: 25),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: catalog.groups.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: limits.maxWidth >= 720 ? 2 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 112,
                    ),
                    itemBuilder: (context, index) {
                      final group = catalog.groups[index];
                      final items = catalog.entries
                          .where((item) => item.groupId == group.id)
                          .toList(growable: false);
                      return Material(
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: _border),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RuqyahGroupReader(
                                group: group,
                                entries: items,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFE8F5FC),
                                  child: Text(
                                    group.id.toString(),
                                    style: const TextStyle(color: _navy),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: _navy,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        group.subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      Text(
                                        '${items.length}টি আয়াত ও দোয়া',
                                        style: const TextStyle(
                                          color: _blue,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: _navy,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class RuqyahGroupReader extends StatefulWidget {
  const RuqyahGroupReader({
    required this.group,
    required this.entries,
    super.key,
  });

  final RuqyahGroup group;
  final List<RuqyahEntry> entries;

  @override
  State<RuqyahGroupReader> createState() => _RuqyahGroupReaderState();
}

class _RuqyahGroupReaderState extends State<RuqyahGroupReader> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _search = TextEditingController();
  final Set<int> _favoriteIds = {};
  bool _onlyFavorites = false;
  bool _loadingAudio = false;
  int? _playingId;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _search.addListener(_changed);
  }

  void _changed() => setState(() {});

  Future<void> _loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _favoriteIds.addAll(
        (p.getStringList('sukun.ruqyah.favorites.v1') ?? const [])
            .map(int.tryParse)
            .whereType<int>(),
      ),
    );
  }

  Future<void> _toggleFavorite(int id) async {
    setState(() {
      if (!_favoriteIds.remove(id)) _favoriteIds.add(id);
    });
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      'sukun.ruqyah.favorites.v1',
      _favoriteIds.map((n) => n.toString()).toList(),
    );
  }

  Future<void> _play(RuqyahEntry entry) async {
    final url = entry.audioUrl;
    if (url == null || _loadingAudio) return;
    setState(() => _loadingAudio = true);
    try {
      if (_playingId == entry.id) {
        if (_player.playing) {
          await _player.pause();
        } else {
          _player.play().ignore();
        }
      } else {
        await _player.stop();
        await _player.setUrl(url);
        _playingId = entry.id;
        _player.play().ignore();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('অডিও চালু হয়নি। আবার চেষ্টা করুন।')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  @override
  void dispose() {
    _search.removeListener(_changed);
    _search.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = _search.text.trim().toLowerCase();
    final entries = widget.entries
        .where((entry) {
          final matches =
              search.isEmpty ||
              entry.title.toLowerCase().contains(search) ||
              entry.bangla.toLowerCase().contains(search) ||
              entry.arabic.contains(search);
          return matches &&
              (!_onlyFavorites || _favoriteIds.contains(entry.id));
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 40),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _navy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.group.subtitle} · ${widget.entries.length}টি আয়াত ও দোয়া',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'আয়াত ও দোয়া খুঁজুন',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: _onlyFavorites ? 'সব দেখুন' : 'ফেভারিট দেখুন',
                    onPressed: () =>
                        setState(() => _onlyFavorites = !_onlyFavorites),
                    icon: Icon(
                      _onlyFavorites ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'কোনো আয়াত বা দোয়া পাওয়া যায়নি।',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final entry in entries)
                Card(
                  key: ValueKey(entry.id),
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${entry.number}. ${entry.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _navy,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'ফেভারিট',
                              onPressed: () => _toggleFavorite(entry.id),
                              icon: Icon(
                                _favoriteIds.contains(entry.id)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                            ),
                            IconButton(
                              tooltip: 'আরবি ও বাংলা কপি',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: '${entry.arabic}\n\n${entry.bangla}',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('কপি করা হয়েছে'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                            ),
                            IconButton.filledTonal(
                              tooltip: entry.audioUrl == null
                                  ? 'এই দোয়ার অডিও পাওয়া যায়নি'
                                  : 'অডিও শুনুন বা থামান',
                              onPressed: entry.audioUrl == null
                                  ? null
                                  : () => _play(entry),
                              icon: Icon(
                                _playingId == entry.id && _player.playing
                                    ? Icons.pause_rounded
                                    : Icons.volume_up_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 23),
                        child: SelectableText(
                          entry.arabic,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 26,
                            height: 2.1,
                            fontFamily: 'serif',
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        title: const Text(
                          'বাংলা অর্থ দেখুন',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _navy),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          18,
                        ),
                        children: [
                          SelectableText(
                            entry.bangla,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (entry.note?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Text(
                              entry.note!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
