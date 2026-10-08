import 'package:flutter/material.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// The video list opens this player directly, with no intermediate
/// "ভিডিও দেখুন" button. The official YouTube embed remains intact.
class SukunYoutubePlayerScreen extends StatelessWidget {
  const SukunYoutubePlayerScreen({
    required this.resource,
    this.autoPlay = false,
    super.key,
  });

  final LinkedResource resource;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) {
    final title = resource.titleBn?.trim().isNotEmpty == true
        ? resource.titleBn!
        : resource.title;
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
          children: [
            SukunYoutubePlayer(resource: resource, autoPlay: autoPlay),
            if (resource.rightsNote?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  resource.rightsNote!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable inline official YouTube player, also used when the user arrives at
/// a resource via a care plan or deep link rather than from the video library.
///
/// YouTube attribution, ads and player-provided links are never obscured.
class SukunYoutubePlayer extends StatefulWidget {
  const SukunYoutubePlayer({
    required this.resource,
    this.autoPlay = false,
    super.key,
  });

  final LinkedResource resource;
  final bool autoPlay;

  @override
  State<SukunYoutubePlayer> createState() => _SukunYoutubePlayerState();
}

class _SukunYoutubePlayerState extends State<SukunYoutubePlayer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final target = resolveResourceMedia(widget.resource);
    if (target?.kind == ResourceMediaKind.youtube &&
        target?.youtubeVideoId != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: target!.youtubeVideoId!,
        autoPlay: widget.autoPlay,
        params: const YoutubePlayerParams(
          mute: false,
          showControls: true,
          showFullscreenButton: true,
          playsInline: true,
          strictRelatedVideos: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const AppEmptyState(
        icon: Icons.videocam_off_outlined,
        title: 'ভিডিও পাওয়া যায়নি',
        message: 'এই উপকরণের বৈধ ইউটিউব ভিডিও আইডি নেই।',
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: YoutubePlayer(
        controller: controller,
        aspectRatio: 16 / 9,
      ),
    );
  }
}
