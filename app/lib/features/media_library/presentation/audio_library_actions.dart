import 'package:flutter/material.dart';
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
          IconButton(
            key: Key('audio-download-${resource.id}'),
            tooltip: 'অফলাইনে ডাউনলোড করুন',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => context.push('/my-media?download=$encoded'),
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
        OutlinedButton.icon(
          key: Key('audio-download-${resource.id}'),
          onPressed: () => context.push('/my-media?download=$encoded'),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('ডাউনলোড'),
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
