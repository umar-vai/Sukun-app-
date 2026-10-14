import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Two independent catalogs: remote canonical Quran content, and the owner's
/// 101 source-book editorial excerpts. Never identify the latter as complete
/// canonical verses or silently mix them into the 114-surah browser.
class QuranTabbedScreen extends StatelessWidget {
  const QuranTabbedScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('কুরআন'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'কুরআন'),
            Tab(text: 'রুকইয়াহ আয়াত'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_CanonicalSurahCatalog(), _RuqyahAyatCatalog()],
      ),
    ),
  );
}

class _QuranContentApi {
  const _QuranContentApi();

  Future<Map<String, dynamic>> fetch(Map<String, Object> payload) async {
    if (!AppEnvironment.isSupabaseConfigured) {
      throw const FormatException('ওয়েব প্রিভিউতে Supabase সংযুক্ত নেই।');
    }
    final result = await Supabase.instance.client.functions.invoke(
      'quran-content',
      body: payload,
    );
    final data = result.data;
    if (data is! Map) {
      throw const FormatException('কুরআন API থেকে সঠিক তথ্য আসেনি।');
    }
    return Map<String, dynamic>.from(data);
  }
}

class _CanonicalSurahCatalog extends StatefulWidget {
  const _CanonicalSurahCatalog();

  @override
  State<_CanonicalSurahCatalog> createState() => _CanonicalSurahCatalogState();
}

class _CanonicalSurahCatalogState extends State<_CanonicalSurahCatalog> {
  late Future<Map<String, dynamic>> _result;

  @override
  void initState() {
    super.initState();
    _result = const _QuranContentApi().fetch({'action': 'chapters'});
  }

  void _retry() => setState(() {
    _result = const _QuranContentApi().fetch({'action': 'chapters'});
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _result,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ConnectionNotice(
            message: 'কুরআন Foundation API-এর নিরাপদ সংযোগ এখনো সক্রিয় নয়।',
            onRetry: _retry,
          );
        }
        final chapters = (snapshot.data?['chapters'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        final isPrelive = snapshot.data?['environment'] == 'prelive';
        return RefreshIndicator(
          onRefresh: () async {
            _retry();
            await _result;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              Text(
                'কুরআনের সূরাসমূহ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'কুরআন Foundation থেকে সূরার নাম, আরবি আয়াত, অনুবাদ ও অনুমোদিত অডিও আনা হয়।',
              ),
              const SizedBox(height: 16),
              if (isPrelive)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'API পরীক্ষামূলক অবস্থায় আছে। বর্তমানে শুধুমাত্র সূরা ফাতিহা ও বাকারা পাওয়া যেতে পারে; পূর্ণ ১১৪ সূরার জন্য Quran Foundation-এর Production API অনুমোদন প্রয়োজন।',
                    ),
                  ),
                ),
              if (chapters.isEmpty)
                const Center(child: Text('এখনো কোনো সূরা পাওয়া যায়নি।')),
              for (final chapter in chapters)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${chapter['id'] ?? ''}'),
                    ),
                    title: Text(_chapterTitle(chapter)),
                    subtitle: Text('${chapter['verses_count'] ?? '—'} আয়াত'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final number = chapter['id'];
                      if (number is int && number >= 1 && number <= 114) {
                        context.push('/resources/quran/$number');
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _chapterTitle(Map<String, dynamic> chapter) {
    final translated = chapter['translated_name'];
    final bangla = translated is Map ? translated['name'] : null;
    final simple = chapter['name_simple'] ?? 'সূরা ${chapter['id']}';
    return bangla is String && bangla.isNotEmpty
        ? '$simple — $bangla'
        : '$simple';
  }
}

class _RuqyahAyatCatalog extends StatefulWidget {
  const _RuqyahAyatCatalog();

  @override
  State<_RuqyahAyatCatalog> createState() => _RuqyahAyatCatalogState();
}

class _RuqyahAyatCatalogState extends State<_RuqyahAyatCatalog> {
  late Future<List<ContentResource>> _result;

  @override
  void initState() {
    super.initState();
    _result = _load();
  }

  Future<List<ContentResource>> _load() async {
    if (!AppEnvironment.isSupabaseConfigured) {
      throw const FormatException('Supabase staging এখনো সংযুক্ত নয়।');
    }
    final response = await Supabase.instance.client
        .from('content_items')
        .select(
          'id,type,title,title_bn,summary,reference_text,source_reference,visibility,status,surah_number,ayah_number',
        )
        .eq('status', 'published')
        .like('slug', 'srg2024-qur-%')
        .order('slug');
    return response.map(ContentResource.fromJson).toList(growable: false);
  }

  void _retry() => setState(() => _result = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContentResource>>(
      future: _result,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ConnectionNotice(
            message: 'রুকইয়াহ আয়াতের তালিকা লোড হয়নি।',
            onRetry: _retry,
          );
        }
        final items = snapshot.data ?? const <ContentResource>[];
        return RefreshIndicator(
          onRefresh: () async {
            _retry();
            await _result;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            children: [
              Text(
                'রুকইয়াহ আয়াত ও অংশ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                '${items.length}টি নির্বাচিত বইভিত্তিক রেকর্ড • মূল কুরআনের সূরা তালিকা থেকে আলাদা',
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'এই পরিবেশে নির্বাচিত রুকইয়াহ আয়াত এখনো প্রকাশ করা হয়নি।',
                  ),
                ),
              for (var index = 0; index < items.length; index++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(items[index].titleBn ?? items[index].title),
                    subtitle: Text(
                      items[index].surahNumber == null
                          ? 'ভূমিকা / স্বতন্ত্র আয়াত নয়'
                          : 'সূরা ${items[index].surahNumber} : ${items[index].ayahNumber} • বইয়ের আয়াত/অংশ',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/resources/${items[index].id}'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class QuranApiSurahScreen extends StatefulWidget {
  const QuranApiSurahScreen({required this.surahNumber, super.key});

  final int surahNumber;

  @override
  State<QuranApiSurahScreen> createState() => _QuranApiSurahScreenState();
}

class _QuranApiSurahScreenState extends State<QuranApiSurahScreen> {
  final AudioPlayer _audio = AudioPlayer();
  final List<Map<String, dynamic>> _verses = [];
  bool _loading = false;
  bool _more = true;
  String? _error;
  String? _playingKey;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _nextPage();
  }

  @override
  void didUpdateWidget(covariant QuranApiSurahScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber) {
      _audio.stop();
      _verses.clear();
      _page = 0;
      _more = true;
      _playingKey = null;
      _nextPage();
    }
  }

  Future<void> _nextPage() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await const _QuranContentApi().fetch({
        'action': 'verses',
        'chapter': widget.surahNumber,
        'page': _page + 1,
      });
      if (!mounted) return;
      final next = (result['verses'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      final pagination = result['pagination'];
      final nextPage = pagination is Map ? pagination['next_page'] : null;
      setState(() {
        _verses.addAll(next);
        _page += 1;
        _more = nextPage is num && nextPage > _page;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'এই সূরার আয়াত লোড করা যাচ্ছে না।');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(String verseKey, String audioUrl) async {
    final uri = Uri.tryParse(audioUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        !{'verses.quran.foundation', 'audio.qurancdn.com'}.contains(uri.host)) {
      return;
    }
    try {
      await _audio.stop();
      if (!mounted) return;
      setState(() => _playingKey = verseKey);
      await _audio.setUrl(audioUrl);
      _audio.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('অডিও চালানো যাচ্ছে না।')));
      }
    }
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('সূরা ${widget.surahNumber}')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'আরবি মূল পাঠ ও বাংলা অনুবাদ Quran Foundation থেকে আসে। যাচাইকৃত বাংলা হরফের উচ্চারণ পাওয়া না গেলে অনুমান করে যোগ করা হয় না।',
          ),
        ),
        for (final verse in _verses) _verseCard(context, verse),
        if (_error != null)
          _ConnectionNotice(message: _error!, onRetry: _nextPage),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading && _more && _error == null)
          OutlinedButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.expand_more),
            label: const Text('পরের আয়াতগুলো দেখুন'),
          ),
      ],
    ),
  );

  Widget _verseCard(BuildContext context, Map<String, dynamic> verse) {
    final translations = (verse['translations'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final bangla = translations
        .where(
          (item) =>
              String(item['language_name'] ?? '').toLowerCase() == 'bengali',
        )
        .toList();
    final latin = translations
        .where((item) => item['resource_id'] == 57)
        .toList();
    final arabic = verse['text_uthmani'] as String? ?? '';
    final audio = verse['audio'];
    final audioUrl = audio is Map ? audio['url'] as String? : null;
    final key = verse['verse_key'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(key, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (audioUrl != null)
                  IconButton(
                    tooltip: 'তিলাওয়াত শুনুন',
                    onPressed: () => _play(key, audioUrl),
                    icon: Icon(
                      _playingKey == key
                          ? Icons.replay
                          : Icons.play_circle_outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: SelectableText(
                arabic,
                style: const TextStyle(fontSize: 28, height: 2.2),
              ),
            ),
            if (bangla.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _plainText(bangla.first['text']),
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),
              if (bangla.first['resource_name'] != null)
                Text(
                  'অনুবাদ: ${bangla.first['resource_name']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            if (latin.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'ল্যাটিন উচ্চারণ: ${_plainText(latin.first['text'])}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _plainText(Object? value) =>
      String(value ?? '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .trim();
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('আবার চেষ্টা করুন'),
          ),
          TextButton(
            onPressed: () => launchUrl(Uri.parse('https://quran.com/')),
            child: const Text('Quran.com খুলুন'),
          ),
        ],
      ),
    ),
  );
}
