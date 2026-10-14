import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/resources/data/online_quran_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Quran and editorial Ruqyah excerpts have separate sources and meanings.
/// Neither category stores private patient data in the client.
class QuranTabsScreen extends StatefulWidget {
  const QuranTabsScreen({super.key});

  @override
  State<QuranTabsScreen> createState() => _QuranTabsScreenState();
}

class _QuranTabsScreenState extends State<QuranTabsScreen> {
  late final Future<List<OnlineSurah>> _surahs =
      const OnlineQuranRepository().allSurahs();
  late final Future<List<ContentResource>> _ruqyah = _loadRuqyah();

  Future<List<ContentResource>> _loadRuqyah() async {
    final rows = await Supabase.instance.client
        .from('content_items')
        .select('id,type,title,title_bn,summary,surah_number,ayah_number,'
            'source_reference,source_url,slug,status')
        .eq('status', 'published')
        .like('slug', 'srg2024-qur-%')
        .order('slug');
    return rows.map((row) => ContentResource.fromJson(row)).toList();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('কুরআন'),
        bottom: const TabBar(tabs: [
          Tab(text: 'কুরআন'),
          Tab(text: 'রুকইয়াহ আয়াত'),
        ]),
      ),
      body: TabBarView(children: [
        FutureBuilder<List<OnlineSurah>>(
          future: _surahs,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _RetryMessage(
                text: 'সূরার তালিকা এখন আনা যাচ্ছে না। ইন্টারনেট সংযোগ পরীক্ষা করুন।',
                onRetry: () => setState(() {}),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final surahs = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final surah = surahs[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${surah.number}')),
                  title: Text(surah.name),
                  subtitle: Text('${surah.verseCount} আয়াত'),
                  trailing: Text(surah.arabicName,
                      style: const TextStyle(fontSize: 19)),
                  onTap: () => context.push(
                      '/resources/quran/${surah.number}'),
                );
              },
            );
          },
        ),
        FutureBuilder<List<ContentResource>>(
          future: _ruqyah,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('রুকইয়াহর আয়াত লোড হয়নি। আবার চেষ্টা করুন।'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(
                child: Text('এই পরিবেশে এখনো কোনো রুকইয়াহ আয়াত প্রকাশিত নেই।'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('বই থেকে সংগৃহীত নির্বাচিত আয়াত ও আয়াতের অংশ। '
                        'এগুলো পূর্ণ কুরআনের বিকল্প নয়।'),
                  );
                }
                final item = items[index - 1];
                return ListTile(
                  leading: CircleAvatar(child: Text('$index')),
                  title: Text(item.titleBn ?? item.title),
                  subtitle: Text(item.surahNumber == null
                      ? 'ভূমিকা · স্বতন্ত্র আয়াত নয়'
                      : 'সূরা ${item.surahNumber} : আয়াত ${item.ayahNumber}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/resources/${item.id}'),
                );
              },
            );
          },
        ),
      ]),
    ),
  );
}

class OnlineQuranSurahScreen extends StatefulWidget {
  const OnlineQuranSurahScreen({required this.surahNumber, super.key});

  final int surahNumber;

  @override
  State<OnlineQuranSurahScreen> createState() => _OnlineQuranSurahScreenState();
}

class _OnlineQuranSurahScreenState extends State<OnlineQuranSurahScreen> {
  late Future<OnlineSurahDetails> _future;
  final AudioPlayer _player = AudioPlayer();
  int? _playingVerse;

  @override
  void initState() {
    super.initState();
    _future = const OnlineQuranRepository().surah(widget.surahNumber);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(OnlineVerse verse) async {
    if (verse.audioUrl == null) return;
    try {
      if (_playingVerse == verse.number && _player.playing) {
        await _player.pause();
        if (mounted) setState(() => _playingVerse = null);
        return;
      }
      await _player.stop();
      await _player.setUrl(verse.audioUrl!);
      if (mounted) setState(() => _playingVerse = verse.number);
      await _player.play();
      if (mounted) setState(() => _playingVerse = null);
    } catch (_) {
      if (mounted) {
        setState(() => _playingVerse = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('অডিও চালানো যায়নি।')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('সূরা ${widget.surahNumber}')),
    body: FutureBuilder<OnlineSurahDetails>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RetryMessage(
            text: 'কুরআনের তথ্য এখন আনা যাচ্ছে না।',
            onRetry: () => setState(() {
              _future = const OnlineQuranRepository().surah(widget.surahNumber);
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.verses.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(children: [
                  Text(data.name, style: Theme.of(context).textTheme.titleLarge),
                  const Text('আরবি: Al Quran Cloud · বাংলা: Bengali translation'),
                  const Text('বাংলা হরফে উচ্চারণের যাচাইকৃত উৎস এখনো যুক্ত হয়নি।',
                      textAlign: TextAlign.center),
                ]),
              );
            }
            final verse = data.verses[index - 1];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text('${widget.surahNumber}:${verse.number}'),
                      const Spacer(),
                      if (verse.audioUrl != null)
                        IconButton(
                          tooltip: 'আয়াত শুনুন',
                          onPressed: () => _toggle(verse),
                          icon: Icon(_playingVerse == verse.number
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Text(verse.arabic,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 25, height: 2)),
                    const SizedBox(height: 14),
                    Text(verse.translationBn,
                        style: const TextStyle(fontSize: 15, height: 1.7)),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('আবার চেষ্টা করুন')),
      ]),
    ),
  );
}
