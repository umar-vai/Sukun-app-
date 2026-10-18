import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/resources/presentation/ruqyah_ayat_library.dart';
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
        children: [_CanonicalSurahCatalog(), RuqyahAyatLibrary()],
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

final Map<int, String> _surahTitles = {};
final Map<int, String> _surahArabicNames = {};

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
            message: 'কুরআন পাঠের API সংযোগ পাওয়া যাচ্ছে না। আবার চেষ্টা করুন।',
            onRetry: _retry,
          );
        }
        final chapters = (snapshot.data?['chapters'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        for (final chapter in chapters) {
          final number = chapter['id'];
          if (number is int) {
            _surahTitles[number] = _chapterTitle(chapter);
            _surahArabicNames[number] = chapter['name_arabic'] as String? ?? '';
          }
        }
        final isPrelive = snapshot.data?['environment'] == 'prelive';
        return RefreshIndicator(
          onRefresh: () async {
            _retry();
            await _result;
          },
          child: QuranSurahList(
            chapters: chapters,
            chapterTitle: _chapterTitle,
            onOpenSurah: (number) => context.push('/resources/quran/$number'),
            isPrelive: isPrelive,
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

/// Shows the real surah list directly: no introductory API/legal copy above it.
/// Edition and reciter attribution remain available in the full surah reader's
/// existing "উৎস তথ্য" action.
@visibleForTesting
class QuranSurahList extends StatelessWidget {
  const QuranSurahList({
    required this.chapters,
    required this.chapterTitle,
    required this.onOpenSurah,
    this.isPrelive = false,
    super.key,
  });

  final List<Map<String, dynamic>> chapters;
  final String Function(Map<String, dynamic>) chapterTitle;
  final ValueChanged<int> onOpenSurah;
  final bool isPrelive;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
    children: [
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
            leading: CircleAvatar(child: Text('${chapter['id'] ?? ''}')),
            title: Text(chapterTitle(chapter)),
            subtitle: Text('${chapter['verses_count'] ?? '—'} আয়াত'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final number = chapter['id'];
              if (number is int && number >= 1 && number <= 114) {
                onOpenSurah(number);
              }
            },
          ),
        ),
    ],
  );
}

class QuranApiSurahScreen extends ConsumerStatefulWidget {
  const QuranApiSurahScreen({
    required this.surahNumber,
    this.initialAyah,
    super.key,
  });

  final int surahNumber;
  final int? initialAyah;

  @override
  ConsumerState<QuranApiSurahScreen> createState() =>
      _QuranApiSurahScreenState();
}

class _QuranApiSurahScreenState extends ConsumerState<QuranApiSurahScreen> {
  final List<Map<String, dynamic>> _verses = [];
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _verseKeys = {};
  AudioPlaybackController? _controller;
  String? _lastAutoScrolled;
  String _surahTitle = 'কুরআন';
  String _arabicTitle = '';
  String? _provider;
  String? _translationEdition;
  String? _recitationEdition;
  bool _loading = false;
  bool _locatingInitialAyah = false;
  bool _showFromTarget = true;
  bool _masterLoading = false;
  bool _verseLoading = false;
  bool _more = true;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _surahTitle = _surahTitles[widget.surahNumber] ?? 'কুরআন';
    _arabicTitle = _surahArabicNames[widget.surahNumber] ?? '';
    _loadTitle();
    final firstPage = _nextPage();
    if (widget.initialAyah != null) {
      _locatingInitialAyah = true;
      unawaited(firstPage.then((_) => _locateInitialAyah()));
    }
  }

  Future<void> _locateInitialAyah() async {
    final target = widget.initialAyah;
    if (target == null || target < 1 || target > 286) {
      if (mounted) setState(() => _locatingInitialAyah = false);
      return;
    }
    final expected = '${widget.surahNumber}:$target';
    for (
      var count = 0;
      mounted &&
          count < 20 &&
          _more &&
          !_verses.any((verse) => verse['verse_key'] == expected);
      count++
    ) {
      await _nextPage();
    }
    if (mounted) setState(() => _locatingInitialAyah = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ref.read(audioPlaybackControllerProvider);
    if (!identical(next, _controller)) {
      _controller?.removeListener(_onAudioChanged);
      _controller = next;
      next.addListener(_onAudioChanged);
    }
  }

  Future<void> _loadTitle() async {
    if (_surahTitles.containsKey(widget.surahNumber)) return;
    try {
      final result = await const _QuranContentApi().fetch({
        'action': 'chapters',
      });
      final chapters = result['chapters'] as List? ?? const [];
      for (final raw in chapters) {
        if (raw is! Map) continue;
        final chapter = Map<String, dynamic>.from(raw);
        final number = chapter['id'];
        if (number is! int) continue;
        final translated = chapter['translated_name'];
        final bn = translated is Map ? translated['name'] as String? : null;
        _surahTitles[number] = bn != null && bn.isNotEmpty
            ? bn
            : chapter['name_simple'] as String? ?? 'কুরআন';
        _surahArabicNames[number] = chapter['name_arabic'] as String? ?? '';
      }
      if (mounted) {
        setState(() {
          _surahTitle = _surahTitles[widget.surahNumber] ?? 'কুরআন';
          _arabicTitle = _surahArabicNames[widget.surahNumber] ?? '';
        });
      }
    } catch (_) {
      // The verse reader remains usable if chapter-label lookup fails.
    }
  }

  void _onAudioChanged() {
    if (!mounted) return;
    final playingKey = _controller?.currentVerseKey;
    if (playingKey != null &&
        playingKey.startsWith('${widget.surahNumber}:') &&
        _lastAutoScrolled != playingKey) {
      _lastAutoScrolled = playingKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _verseKeys[playingKey]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.22,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        } else if (_scroll.hasClients && _verses.isNotEmpty) {
          final index = _verses.indexWhere((v) => v['verse_key'] == playingKey);
          if (index >= 0) {
            final approximate =
                _scroll.position.maxScrollExtent * index / _verses.length;
            unawaited(
              _scroll.animateTo(
                approximate.clamp(0.0, _scroll.position.maxScrollExtent),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
              ),
            );
          }
        }
      });
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant QuranApiSurahScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber) {
      _verses.clear();
      _verseKeys.clear();
      _page = 0;
      _more = true;
      _error = null;
      _lastAutoScrolled = null;
      _surahTitle = _surahTitles[widget.surahNumber] ?? 'কুরআন';
      _arabicTitle = _surahArabicNames[widget.surahNumber] ?? '';
      _locatingInitialAyah = widget.initialAyah != null;
      _showFromTarget = true;
      _loadTitle();
      final firstPage = _nextPage();
      if (widget.initialAyah != null) {
        unawaited(firstPage.then((_) => _locateInitialAyah()));
      }
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
        _provider = result['provider'] as String? ?? 'Quran Foundation';
        _translationEdition = result['translation_name'] as String?;
        _recitationEdition = result['recitation_name'] as String?;
        _page++;
        _more = nextPage is num && nextPage > _page;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'এই সূরার আয়াত লোড করা যাচ্ছে না।');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _audioUrl(Map<String, dynamic> verse) {
    final audio = verse['audio'];
    return audio is Map ? audio['url'] as String? : null;
  }

  Future<void> _playVerse(Map<String, dynamic> verse) async {
    if (_verseLoading || _masterLoading) return;
    final url = _audioUrl(verse);
    final key = verse['verse_key'] as String?;
    if (key == null || url == null) return;
    final controller = ref.read(audioPlaybackControllerProvider);
    if (controller.currentVerseKey == key && !controller.isQuranSequence) {
      if (controller.player.playing) {
        await controller.pause();
      } else {
        controller.resumeCurrent();
      }
      return;
    }
    setState(() => _verseLoading = true);
    try {
      await controller.loadQuran(
        title: _surahTitle,
        verses: [QuranVerseAudio(key: key, url: url)],
      );
      controller.resumeCurrent();
    } catch (_) {
      if (mounted) _showPlaybackError();
    } finally {
      if (mounted) setState(() => _verseLoading = false);
    }
  }

  Future<void> _playEntireSurah() async {
    if (_masterLoading || _verseLoading || _loading) return;
    final controller = ref.read(audioPlaybackControllerProvider);
    if (controller.isQuranSequence &&
        controller.currentVerseKey?.startsWith('${widget.surahNumber}:') ==
            true) {
      if (controller.player.playing) {
        await controller.pause();
      } else {
        controller.resumeCurrent();
      }
      return;
    }
    if (_verses.isEmpty) return;
    setState(() => _masterLoading = true);
    try {
      // Fetch all pages once so one just_audio playlist can handle transitions
      // while other routes remain open. No permanent on-device verse corpus.
      final allVerses = List<Map<String, dynamic>>.from(_verses);
      var nextPage = _more ? _page + 1 : null;
      while (nextPage != null) {
        final result = await const _QuranContentApi().fetch({
          'action': 'verses',
          'chapter': widget.surahNumber,
          'page': nextPage,
        });
        final extra = (result['verses'] as List? ?? const [])
            .whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v));
        allVerses.addAll(extra);
        final pagination = result['pagination'];
        final candidate = pagination is Map ? pagination['next_page'] : null;
        nextPage = candidate is num ? candidate.toInt() : null;
        if (nextPage != null && nextPage > 20) {
          throw const FormatException('Invalid Quran pagination');
        }
      }
      final playlist = <QuranVerseAudio>[];
      for (final verse in allVerses) {
        final key = verse['verse_key'] as String?;
        final url = _audioUrl(verse);
        if (key == null || url == null) {
          throw const FormatException('Missing Quran verse audio');
        }
        playlist.add(QuranVerseAudio(key: key, url: url));
      }
      await controller.loadQuran(title: _surahTitle, verses: playlist);
      if (mounted) {
        setState(() {
          _verses
            ..clear()
            ..addAll(allVerses);
          _more = false;
          _page = (allVerses.length / 50).ceil();
        });
      }
      controller.resumeCurrent();
    } catch (_) {
      if (mounted) _showPlaybackError();
    } finally {
      if (mounted) setState(() => _masterLoading = false);
    }
  }

  void _showPlaybackError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('তিলাওয়াত চালু হয়নি। আবার চেষ্টা করুন।')),
    );
  }

  void _showSourceDetails() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('উৎস তথ্য', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('কুরআন পাঠ: ${_provider ?? 'Quran Content API'}'),
              if (_translationEdition != null)
                Text('বাংলা অনুবাদ: $_translationEdition'),
              if (_recitationEdition != null)
                Text('তিলাওয়াত: $_recitationEdition'),
              const SizedBox(height: 8),
              const Text(
                'সকল অনুবাদ ও তিলাওয়াতের স্বত্ব সংশ্লিষ্ট প্রকাশক ও কারির।',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onAudioChanged);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(audioPlaybackControllerProvider);
    final sameSurahPlaying =
        controller.isQuranSequence &&
        controller.currentVerseKey?.startsWith('${widget.surahNumber}:') ==
            true &&
        controller.player.playing;
    return Scaffold(
      appBar: AppBar(
        title: Text(_surahTitle),
        actions: [
          IconButton(
            tooltip: 'উৎস তথ্য',
            onPressed: _showSourceDetails,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 210),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _surahTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (_arabicTitle.isNotEmpty)
                          Text(
                            _arabicTitle,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.amiriQuran(
                              fontSize: 27,
                              height: 1.7,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_masterLoading)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  else
                    IconButton.filledTonal(
                      tooltip: sameSurahPlaying
                          ? 'পূর্ণ সূরা বিরতি দিন'
                          : 'সম্পূর্ণ সূরা শুনুন',
                      onPressed: _verses.isEmpty ? null : _playEntireSurah,
                      iconSize: 30,
                      icon: Icon(
                        sameSurahPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (widget.initialAyah != null && _showFromTarget) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'নির্ধারিত আয়াত: ${widget.surahNumber}:${widget.initialAyah}',
                    ),
                    if (_locatingInitialAyah) const LinearProgressIndicator(),
                    if (!_locatingInitialAyah)
                      TextButton(
                        onPressed: () =>
                            setState(() => _showFromTarget = false),
                        child: const Text('সূরার শুরু থেকে পড়ুন'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          for (final verse in _verses)
            if (!_showFromTarget ||
                widget.initialAyah == null ||
                (int.tryParse(
                          (verse['verse_key'] as String? ?? '').split(':').last,
                        ) ??
                        0) >=
                    widget.initialAyah!)
              _verseCard(context, verse),
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
  }

  Widget _verseCard(BuildContext context, Map<String, dynamic> verse) {
    final translations = (verse['translations'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final bangla = translations
        .where(
          (item) =>
              (item['language_name'] ?? '').toString().toLowerCase() ==
              'bengali',
        )
        .toList();
    final arabic = verse['text_uthmani'] as String? ?? '';
    final audioUrl = _audioUrl(verse);
    final key = verse['verse_key'] as String? ?? '';
    final controller = ref.read(audioPlaybackControllerProvider);
    final highlighted =
        controller.currentVerseKey == key && controller.player.playing;
    return Container(
      key: _verseKeys.putIfAbsent(key, GlobalKey.new),
      child: Card(
        color: highlighted ? const Color(0xFFE1F3FC) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: highlighted ? const Color(0xFF0A70A8) : Colors.transparent,
            width: highlighted ? 2 : 0,
          ),
        ),
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
                  if (highlighted)
                    const Icon(
                      Icons.equalizer_rounded,
                      color: Color(0xFF0A70A8),
                    ),
                  if (audioUrl != null)
                    IconButton(
                      tooltip: highlighted && !controller.isQuranSequence
                          ? 'আয়াত বিরতি দিন'
                          : 'শুধু এই আয়াত শুনুন',
                      onPressed: _verseLoading || _masterLoading
                          ? null
                          : () => _playVerse(verse),
                      icon: Icon(
                        highlighted && !controller.isQuranSequence
                            ? Icons.pause_circle_outline
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
                  textAlign: TextAlign.right,
                  // Keep the Uthmani text untouched; improve Arabic glyph
                  // shaping and harakat clarity in the canonical surah reader.
                  // Bengali translation and other screens retain their fonts.
                  style: GoogleFonts.amiriQuran(
                    fontSize: MediaQuery.sizeOf(context).width < 500 ? 28 : 32,
                    height: 2.15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (bangla.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _plainText(bangla.first['text']),
                  style: const TextStyle(fontSize: 15, height: 1.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _plainText(Object? value) => (value ?? '')
      .toString()
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
