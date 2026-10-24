import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/media_library/data/offline_library.dart';

/// Keep offline status consistent across resource cards and the local library.
class AudioLibraryActions extends ConsumerStatefulWidget {
  const AudioLibraryActions({
    required this.resource,
    this.compact = false,
    super.key,
  });

  final LinkedResource resource;
  final bool compact;

  static bool supports(LinkedResource resource) =>
      resource.type == 'audio' &&
      resolveResourceMedia(resource)?.kind == ResourceMediaKind.audio;

  @override
  ConsumerState<AudioLibraryActions> createState() =>
      _AudioLibraryActionsState();
}

class _AudioLibraryActionsState extends ConsumerState<AudioLibraryActions> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openForCurrentUser();
    });
  }

  void _openForCurrentUser() {
    final owner = ref.read(appSessionProvider).value?.userId ?? 'guest';
    unawaited(ref.read(offlineLibraryProvider).open(owner));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppSession>>(appSessionProvider, (before, after) {
      if (before?.value?.userId != after.value?.userId) {
        _openForCurrentUser();
      }
    });
    if (!AudioLibraryActions.supports(widget.resource)) {
      return const SizedBox.shrink();
    }

    final library = ref.watch(offlineLibraryProvider);
    final encoded = Uri.encodeQueryComponent(widget.resource.id);

    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final downloaded = library.ready && library.contains(widget.resource.id);

        if (widget.compact) {
          return Wrap(
            spacing: 2,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: Key('audio-add-${widget.resource.id}'),
                tooltip: 'প্লেলিস্টে যোগ করুন',
                icon: const Icon(Icons.playlist_add_rounded),
                onPressed: () => context.push('/my-media?add=$encoded'),
              ),
              if (downloaded)
                Tooltip(
                  message: 'ডাউনলোড করা',
                  child: Icon(
                    Icons.download_done_rounded,
                    key: Key('audio-downloaded-${widget.resource.id}'),
                    semanticLabel: 'ডাউনলোড করা',
                  ),
                )
              else
                IconButton(
                  key: Key('audio-download-${widget.resource.id}'),
                  tooltip: 'ডাউনলোড',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => context.push('/my-media?download=$encoded'),
                ),
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: Key('audio-add-${widget.resource.id}'),
              onPressed: () => context.push('/my-media?add=$encoded'),
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: const Text('প্লেলিস্টে যোগ করুন'),
            ),
            if (downloaded)
              Chip(
                key: Key('audio-downloaded-${widget.resource.id}'),
                avatar: const Icon(Icons.download_done_rounded, size: 18),
                label: const Text('ডাউনলোড করা'),
              )
            else
              OutlinedButton.icon(
                key: Key('audio-download-${widget.resource.id}'),
                onPressed: () => context.push('/my-media?download=$encoded'),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('ডাউনলোড'),
              ),
          ],
        );
      },
    );
  }
}

class AudioLibraryShortcut extends StatelessWidget {
  const AudioLibraryShortcut({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        key: const Key('open-my-audio-library'),
        tooltip: 'আমার প্লেলিস্ট ও ডাউনলোড',
        icon: const Icon(Icons.library_music_outlined),
        onPressed: () => context.push('/my-media'),
      );
    }
    return OutlinedButton.icon(
      key: const Key('open-my-audio-library'),
      onPressed: () => context.push('/my-media'),
      icon: const Icon(Icons.library_music_outlined),
      label: const Text('আমার প্লেলিস্ট ও ডাউনলোড'),
    );
  }
}
