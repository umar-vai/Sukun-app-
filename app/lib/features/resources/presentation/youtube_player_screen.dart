import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class SukunYoutubePlayerScreen extends StatefulWidget {
  const SukunYoutubePlayerScreen({required this.resource, super.key});

  final LinkedResource resource;

  @override
  State<SukunYoutubePlayerScreen> createState() =>
      _SukunYoutubePlayerScreenState();
}

class _SukunYoutubePlayerScreenState extends State<SukunYoutubePlayerScreen> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final target = resolveResourceMedia(widget.resource);
    final videoId = target?.youtubeVideoId;
    if (target?.kind == ResourceMediaKind.youtube && videoId != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          mute: false,
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
      return Scaffold(
        appBar: AppBar(title: const Text('Video')),
        body: const AppEmptyState(
          icon: Icons.videocam_off_outlined,
          title: 'Video unavailable',
          message: 'This resource does not have a valid YouTube video ID.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          SukunPageIntro(
            eyebrow: 'External video',
            title: widget.resource.titleBn?.trim().isNotEmpty == true
                ? widget.resource.titleBn!
                : widget.resource.title,
            subtitle: widget.resource.titleBn?.trim().isNotEmpty == true
                ? widget.resource.title
                : 'Played through the official YouTube player.',
            trailing: const SukunIconBadge(
              icon: Icons.play_circle_outline_rounded,
              size: 54,
            ),
          ),
          const SizedBox(height: 22),
          SukunSurface(
            tone: SukunSurfaceTone.navy,
            showBorder: false,
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: YoutubePlayer(controller: controller),
            ),
          ),
          if (widget.resource.rightsNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 22),
            SukunSurface(
              tone: SukunSurfaceTone.soft,
              showBorder: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rights & source',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(widget.resource.rightsNote!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SukunSurface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: SukunColors.deepTide,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'YouTube playback uses the official IFrame Player API. Sukun Life does not extract or redistribute the audio track.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
