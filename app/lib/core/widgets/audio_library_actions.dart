import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One action menu for CMS-backed audio wherever it appears in the app.
///
/// The library re-fetches the resource with the current session and checks
/// publication, visibility and download rights. A patient-linked URL or a
/// playing stream alone never confers offline or playlist permissions.
enum AudioLibraryAction { playlist, download, library }

String audioLibraryPath(AudioLibraryAction action, String resourceId) {
  return switch (action) {
    AudioLibraryAction.playlist =>
      '/my-media?add=${Uri.encodeQueryComponent(resourceId)}',
    AudioLibraryAction.download =>
      '/my-media?download=${Uri.encodeQueryComponent(resourceId)}',
    AudioLibraryAction.library => '/my-media',
  };
}

/// For use next to any playable, CMS-backed audio item. Streaming sources
/// without a canonical content ID (such as verse audio from an external API)
/// should not use this menu until that source has its own approved save policy.
class AudioLibraryActions extends StatelessWidget {
  const AudioLibraryActions({
    required this.resourceId,
    this.compact = false,
    super.key,
  });

  final String resourceId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (resourceId.trim().isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<AudioLibraryAction>(
      key: Key('audio-library-actions-$resourceId'),
      tooltip: 'প্লেলিস্ট, ডাউনলোড ও আমার লাইব্রেরি',
      icon: Icon(compact ? Icons.more_vert_rounded : Icons.library_music_outlined),
      onSelected: (action) => context.push(audioLibraryPath(action, resourceId)),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AudioLibraryAction.playlist,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_add_rounded),
              SizedBox(width: 12),
              Text('প্লেলিস্টে যুক্ত করুন'),
            ],
          ),
        ),
        PopupMenuItem(
          value: AudioLibraryAction.download,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_outlined),
              SizedBox(width: 12),
              Text('অফলাইনে ডাউনলোড'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: AudioLibraryAction.library,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_music_outlined),
              SizedBox(width: 12),
              Text('আমার লাইব্রেরি দেখুন'),
            ],
          ),
        ),
      ],
    );
  }
}
