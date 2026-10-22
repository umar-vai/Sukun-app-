import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/external_resource_launcher.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/presentation/ayah_reading_card.dart';
import 'package:sukun_life/features/resources/presentation/pdf_reader_screen.dart';
import 'package:sukun_life/features/resources/presentation/youtube_player_screen.dart';

class ResourceDetailScreen extends ConsumerStatefulWidget {
  const ResourceDetailScreen({
    super.key,
    required this.resourceId,
    this.loadAudioResource,
  });

  final String resourceId;

  /// Test seam: the production player uses the existing shared audio engine.
  final Future<void> Function(LinkedResource)? loadAudioResource;

  @override
  ConsumerState<ResourceDetailScreen> createState() =>
      _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends ConsumerState<ResourceDetailScreen> {
  late Future<ContentResource?> _resource;

  @override
  void initState() {
    super.initState();
    _resource = _load();
  }

  @override
  void didUpdateWidget(covariant ResourceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resourceId != widget.resourceId) {
      // GoRouter may reuse this State when a different resource is opened.
      // Never render content fetched for the previous resource identifier.
      _resource = _load();
    }
  }

  Future<ContentResource?> _load() =>
      ref.read(resourcesRepositoryProvider).getResource(widget.resourceId);

  void _reload() {
    setState(() {
      _resource = _load();
    });
  }

  Future<void> _openMedia(ContentResource resource) async {
    final target = resolveResourceMedia(resource.linkedResource);
    if (target == null) {
      _showError('এই উপকরণের লিংকটি এখন কাজ করছে না।');
      return;
    }
    if (target.kind == ResourceMediaKind.audio) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) =>
              AudioPlayerScreen(resource: resource.linkedResource),
        ),
      );
      return;
    }
    if (target.kind == ResourceMediaKind.pdf) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) =>
              PdfReaderScreen(resource: resource.linkedResource),
        ),
      );
      return;
    }
    try {
      await ref.read(resourceLauncherProvider).open(resource.linkedResource);
    } catch (error) {
      _showError('উপকরণটি খোলা যাচ্ছে না। আবার চেষ্টা করুন।');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Public resource routes remain mounted across sign-in/sign-out. Re-fetch
    // with the *new* database-verified identity instead of retaining content
    // from the previous Patient/Admin in the same browser tab.
    ref.listen<AsyncValue<AppSession>>(appSessionProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      // Initial loading -> Guest is not an account switch.
      if (before?.userId == null && after?.userId == null) return;
      if (before?.userId != after?.userId || before?.role != after?.role) {
        _reload();
      }
    });
    return FutureBuilder<ContentResource?>(
      future: _resource,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('ইসলামিক উপকরণ')),
            body: AppLoadingState(label: 'উপকরণটি আনা হচ্ছে…'),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('ইসলামিক উপকরণ')),
            body: AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: _reload,
            ),
          );
        }
        final resource = snapshot.data;
        if (resource == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('ইসলামিক উপকরণ')),
            body: AppEmptyState(
              title: 'উপকরণটি পাওয়া যায়নি',
              message:
                  'এই উপকরণটি এখনো প্রকাশ করা হয়নি অথবা আপনার জন্য দেওয়া হয়নি।',
            ),
          );
        }
        // A playable audio item goes straight to its full player. Retain
        // the existing resource route so deep links, Guest/Patient RLS
        // checks, refreshes and browser back all keep working.
        if (resource.type == 'audio' &&
            resolveResourceMedia(resource.linkedResource)?.kind ==
                ResourceMediaKind.audio) {
          return AudioPlayerScreen(
            resource: resource.linkedResource,
            loadResource: widget.loadAudioResource,
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('ইসলামিক উপকরণ'),
            actions: [
              if (resolveResourceMedia(resource.linkedResource)?.kind ==
                  ResourceMediaKind.pdf)
                IconButton(
                  onPressed: () => context.push(
                    '/my-media?download=${Uri.encodeQueryComponent(resource.id)}',
                  ),
                  tooltip: 'PDF অফলাইনে সংরক্ষণ করুন',
                  icon: const Icon(Icons.download_outlined),
                ),
              if (ref.watch(appSessionProvider).value?.isSuperAdmin == true)
                IconButton(
                  onPressed: () async {
                    await context.push('/admin/content/${resource.id}/edit');
                    if (mounted) _reload();
                  },
                  tooltip: 'উপকরণ সম্পাদনা করুন',
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  SukunStatusPill(
                    label: _typeLabel(resource.type),
                    tone: SukunStatusTone.brand,
                  ),
                  if (!resource.isRuqyahBdAudio &&
                      (resource.referenceText?.isNotEmpty == true ||
                          resource.sourceReference?.isNotEmpty == true))
                    const SukunStatusPill(
                      label: 'উৎস উল্লেখ আছে',
                      tone: SukunStatusTone.brand,
                      icon: Icons.menu_book_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SukunPageIntro(
                title: resource.titleBn?.isNotEmpty == true
                    ? resource.titleBn!
                    : resource.title,
                subtitle: resource.titleBn?.isNotEmpty == true
                    ? resource.title
                    : resource.summary,
              ),
              if (ref.watch(appSessionProvider).value?.isAuthenticated ==
                  true) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/my-routines?resourceId=${Uri.encodeQueryComponent(resource.id)}',
                  ),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('আমার রুটিনে যুক্ত করুন'),
                ),
              ],
              if (resource.titleBn?.isNotEmpty == true)
                const SizedBox(height: 4),
              _Section(
                label: 'সংক্ষেপে',
                value: resource.isRuqyahBdAudio
                    ? null
                    : resource.titleBn?.isNotEmpty == true
                    ? resource.summary
                    : null,
              ),
              if (resource.arabicText?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: AyahReadingCard(
                    arabicText: resource.arabicText!,
                    transliteration: resource.transliteration,
                  ),
                ),
              _Section(
                label: 'বাংলা',
                value: resource.banglaText,
                bangla: true,
              ),
              if (resource.arabicText?.trim().isNotEmpty != true)
                _Section(label: 'উচ্চারণ', value: resource.transliteration),
              _Section(label: 'অনুবাদ', value: resource.translation),
              _Section(
                label: 'নির্দেশনা',
                value: resource.isRuqyahBdAudio ? null : resource.body,
              ),
              if (resource.isRuqyahBdAudio)
                const _Section(label: 'অডিও উৎস', value: 'রুকইয়াহ সাপোর্ট বিডি')
              else
                _Section(
                  label: 'তথ্যসূত্র',
                  value: resource.referenceText ?? resource.sourceReference,
                ),
              // Publication rights, internal book paragraph IDs and review
              // metadata remain accessible to Admin; not to listeners.
              if (resolveResourceMedia(resource.linkedResource)?.kind ==
                  ResourceMediaKind.youtube) ...[
                const SizedBox(height: 20),
                SukunYoutubePlayer(
                  resource: resource.linkedResource,
                  autoPlay: false,
                ),
              ] else if (resolveResourceMedia(resource.linkedResource) !=
                  null) ...[
                const SizedBox(height: 24),
                SukunSurface(
                  tone: SukunSurfaceTone.navy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'উপকরণটি খুলুন',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: SukunColors.nightNavy,
                        ),
                        onPressed: () => _openMedia(resource),
                        icon: Icon(_openIcon(resource.mediaSourceType)),
                        label: Text(_openLabel(resource.mediaSourceType)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, this.value, this.bangla = false});

  final String label;
  final String? value;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    if (value?.trim().isNotEmpty != true) return const SizedBox.shrink();
    final base = bangla
        ? SukunTypography.banglaBody(
            textStyle: Theme.of(context).textTheme.bodyLarge,
          ).copyWith(height: 1.75)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SukunSurface(
        tone: SukunSurfaceTone.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(value!, style: base),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(String type) => switch (type) {
  'quran' => 'কুরআন',
  'hadith' => 'হাদিস',
  'dua' => 'দোয়া',
  'amal' => 'আমল',
  'audio' => 'অডিও',
  'video' => 'ভিডিও',
  'book' || 'book_chapter' => 'বই',
  'pdf' => 'পিডিএফ',
  'article' => 'লেখা',
  _ => 'উপকরণ',
};

String _openLabel(String? mediaType) => switch (mediaType) {
  'direct_audio_url' => 'অডিও শুনুন',
  'youtube' => 'ভিডিও দেখুন',
  'direct_video_url' => 'ভিডিও চালু করুন',
  'external_pdf' => 'পিডিএফ খুলুন',
  _ => 'উপকরণ খুলুন',
};

IconData _openIcon(String? mediaType) => switch (mediaType) {
  'direct_audio_url' => Icons.play_arrow_rounded,
  'youtube' || 'direct_video_url' => Icons.ondemand_video_outlined,
  'external_pdf' => Icons.picture_as_pdf_outlined,
  _ => Icons.open_in_new,
};
