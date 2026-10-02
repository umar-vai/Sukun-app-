import 'package:flutter/material.dart';
import 'package:sukun_life/core/media/resource_media.dart';
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
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This video does not have a valid YouTube ID.'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: YoutubePlayer(controller: controller),
          ),
          const SizedBox(height: 22),
          Text(
            widget.resource.titleBn?.trim().isNotEmpty == true
                ? widget.resource.titleBn!
                : widget.resource.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (widget.resource.titleBn?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(widget.resource.title),
          ],
          if (widget.resource.rightsNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 22),
            Text(
              'Rights & source',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(widget.resource.rightsNote!),
          ],
          const SizedBox(height: 18),
          Text(
            'YouTube playback uses the official IFrame Player API. Sukun Life does not extract or redistribute the audio track.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
