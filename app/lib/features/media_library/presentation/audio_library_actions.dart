import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/media_library/data/offline_library.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// Two consistent actions for an audio resource, wherever it is discovered.
///
/// These navigate only with the CMS resource ID. The library re-fetches the
/// current resource and checks publication, visibility and offline rights.
/// Never put raw URLs, patient media or private bytes into a playlist.
class AudioLibraryActions extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!supports(resource)) return const SizedBox.shrink();
    final encoded = Uri.encodeQueryComponent(resource.id);
    if (compact) {
      return Wrap(
        spacing: 2,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: Key('audio-add-${resource.id}'),
            tooltip: 'প্লেলিস্টে যোগ করুন',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => context.push('/my-media?add=$encoded'),
          ),
          OfflineDownloadAction(
            key: Key('audio-download-${resource.id}'),
            resourceId: resource.id,
            compact: true,
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          key: Key('audio-add-${resource.id}'),
          onPressed: () => context.push('/my-media?add=$encoded'),
          icon: const Icon(Icons.playlist_add_rounded, size: 18),
          label: const Text('প্লেলিস্টে যোগ করুন'),
        ),
        OfflineDownloadAction(
          key: Key('audio-download-${resource.id}'),
          resourceId: resource.id,
        ),
      ],
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

/// Shows the current device's saved state wherever a public media item
/// appears. The same offline library owns the bytes and metadata.
class OfflineDownloadAction extends ConsumerStatefulWidget {
  const OfflineDownloadAction({
    required this.resourceId,
    this.compact = false,
    this.iconOnly = false,
    super.key,
  });

  final String resourceId;
  final bool compact;
  final bool iconOnly;

  @override
  ConsumerState<OfflineDownloadAction> createState() =>
      _OfflineDownloadActionState();
}

class _OfflineDownloadActionState
    extends ConsumerState<OfflineDownloadAction> {
  String? _openedOwner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openForCurrentOwner();
    });
  }

  void _openForCurrentOwner() {
    final owner = ref.read(appSessionProvider).value?.userId ?? 'guest';
    if (_openedOwner == owner) return;
    _openedOwner = owner;
    unawaited(ref.read(offlineLibraryProvider).open(owner));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSessionProvider, (_, _) => _openForCurrentOwner());
    final library = ref.watch(offlineLibraryProvider);
    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final downloaded = library.ready && library.contains(widget.resourceId);
        final label = downloaded ? 'ডাউনলোড হয়েছে' : 'ডাউনলোড';
        final target =
            '/my-media?download=${Uri.encodeQueryComponent(widget.resourceId)}';
        if (widget.compact || widget.iconOnly) {
          return IconButton(
            tooltip: label,
            onPressed: () => context.push(target),
            icon: Icon(
              downloaded
                  ? Icons.download_done_rounded
                  : Icons.download_outlined,
            ),
          );
        }
        return OutlinedButton.icon(
          onPressed: () => context.push(target),
          icon: Icon(
            downloaded ? Icons.download_done_rounded : Icons.download_outlined,
            size: 18,
          ),
          label: Text(label),
        );
      },
    );
  }
}
