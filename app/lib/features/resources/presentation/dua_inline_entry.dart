import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/ayah_reading_card.dart';
import 'package:sukun_life/features/resources/presentation/public_resource_copy.dart';

/// One dua or amal shown in full on its category page: a mini title, the
/// text, and (when it has audio) a play button that loads the recording into
/// the shared floating player instead of opening another page.
///
/// List queries leave the text out, so the full record is fetched by its
/// resource ID. If that fails the entry still shows its title and audio.
class DuaInlineEntry extends ConsumerStatefulWidget {
  const DuaInlineEntry({required this.resource, super.key});

  final ContentResource resource;

  @override
  ConsumerState<DuaInlineEntry> createState() => _DuaInlineEntryState();
}

class _DuaInlineEntryState extends ConsumerState<DuaInlineEntry> {
  late Future<ContentResource?> _full;

  @override
  void initState() {
    super.initState();
    _full = _load();
  }

  @override
  void didUpdateWidget(covariant DuaInlineEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource.id != widget.resource.id) _full = _load();
  }

  // async so a synchronous repository failure becomes a Future error that the
  // FutureBuilder handles, rather than throwing while the page is building.
  Future<ContentResource?> _load() async =>
      ref.read(resourcesRepositoryProvider).getResource(widget.resource.id);

  bool get _hasAudio =>
      resolveResourceMedia(widget.resource.linkedResource)?.kind ==
      ResourceMediaKind.audio;

  bool get _hasOtherMedia =>
      !_hasAudio &&
      resolveResourceMedia(widget.resource.linkedResource) != null;

  Future<void> _toggleAudio() async {
    final controller = ref.read(audioPlaybackControllerProvider);
    final linked = widget.resource.linkedResource;
    try {
      final isCurrent =
          controller.resource != null &&
          !audioResourceNeedsReload(controller.resource, linked);
      if (isCurrent) {
        if (controller.player.playing) {
          await controller.pause();
        } else {
          controller.resumeCurrent();
        }
        return;
      }
      await controller.load(linked);
      controller.resumeCurrent();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('অডিও চালু করা যাচ্ছে না। আবার চেষ্টা করুন।'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.resource;
    final title = item.titleBn?.trim().isNotEmpty == true
        ? item.titleBn!
        : item.title;
    final signedIn = ref.watch(appSessionProvider).value?.isAuthenticated;
    return SukunSurface(
      key: Key('dua-card-${item.id}'),
      tone: SukunSurfaceTone.white,
      child: FutureBuilder<ContentResource?>(
        future: _full,
        builder: (context, snapshot) {
          final full = snapshot.data;
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final source = full ?? item;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: SukunTypography.banglaBody(
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: LinearProgressIndicator(),
                ),
              if (full?.arabicText?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AyahReadingCard(
                    arabicText: full!.arabicText!,
                    transliteration: full.transliteration,
                  ),
                ),
              _TextBlock(
                label: 'পড়ার নিয়ম',
                value: publicResourceInstructions(source.summary),
              ),
              _TextBlock(label: 'বাংলা', value: full?.banglaText),
              if (full?.arabicText?.trim().isNotEmpty != true)
                _TextBlock(label: 'উচ্চারণ', value: full?.transliteration),
              _TextBlock(label: 'অনুবাদ', value: full?.translation),
              _TextBlock(
                label: 'নির্দেশনা',
                value: publicResourceInstructions(full?.body),
              ),
              _TextBlock(
                label: 'রেফারেন্স',
                value: _publicReference(full?.referenceText),
              ),
              if (_hasAudio || _hasOtherMedia || signedIn == true)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_hasAudio) _audioButton(),
                      if (_hasOtherMedia)
                        OutlinedButton.icon(
                          key: Key('dua-media-${item.id}'),
                          onPressed: () => context.push(
                            '/resources/${Uri.encodeComponent(item.id)}',
                          ),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('মিডিয়া খুলুন'),
                        ),
                      if (signedIn == true)
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/my-routines?resourceId=${Uri.encodeQueryComponent(item.id)}',
                          ),
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: const Text('আমার রুটিনে যুক্ত করুন'),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _audioButton() {
    final controller = ref.watch(audioPlaybackControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current =
            controller.resource != null &&
            !audioResourceNeedsReload(
              controller.resource,
              widget.resource.linkedResource,
            );
        final playing = current && controller.player.playing;
        return FilledButton.icon(
          key: Key('dua-audio-${widget.resource.id}'),
          onPressed: () => unawaited(_toggleAudio()),
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(playing ? 'থামান' : 'অডিও শুনুন'),
        );
      },
    );
  }
}

/// A hadith reference, never an editor's repeat-count or review note.
String? _publicReference(String? raw) {
  final value = publicResourceInstructions(raw);
  if (value == null) return null;
  final editorNote = RegExp(
    r'Repeat count from approved source|কতবার',
    caseSensitive: false,
  );
  return editorNote.hasMatch(value) ? null : value;
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<AppDisplayPreferences>(
            valueListenable: AppDisplaySettings.instance,
            builder: (context, reading, _) => SelectableText(
              text,
              style: SukunTypography.banglaBody(
                textStyle: theme.textTheme.bodyLarge,
              ).copyWith(height: 1.75 * reading.readerLineSpacing),
            ),
          ),
        ],
      ),
    );
  }
}
