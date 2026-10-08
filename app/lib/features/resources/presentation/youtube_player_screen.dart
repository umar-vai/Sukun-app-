import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/resources/domain/video_load_phase.dart';
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
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
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
  StreamSubscription<YoutubePlayerValue>? _statusSubscription;
  Timer? _loadTimeout;
  VideoLoadPhase _phase = VideoLoadPhase.loading;
  bool _hasLoaded = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startPlayer();
  }

  @override
  void didUpdateWidget(covariant SukunYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldVideo = resolveResourceMedia(oldWidget.resource)?.youtubeVideoId;
    final newVideo = resolveResourceMedia(widget.resource)?.youtubeVideoId;
    if (oldVideo != newVideo || oldWidget.autoPlay != widget.autoPlay) {
      _startPlayer();
    }
  }

  void _startPlayer() {
    final generation = ++_generation;
    _loadTimeout?.cancel();
    _statusSubscription?.cancel();
    _controller?.close();
    _controller = null;
    _phase = VideoLoadPhase.loading;
    _hasLoaded = false;

    final target = resolveResourceMedia(widget.resource);
    if (target?.kind != ResourceMediaKind.youtube ||
        target?.youtubeVideoId == null) {
      return;
    }

    final controller = YoutubePlayerController.fromVideoId(
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
    _controller = controller;
    _statusSubscription = controller.stream.listen(
      (value) {
        if (!mounted || generation != _generation) return;
        final next = videoLoadPhase(value, hasLoaded: _hasLoaded);
        if (_phase == VideoLoadPhase.failed &&
            next == VideoLoadPhase.loading) {
          return;
        }
        if (next == VideoLoadPhase.ready ||
            next == VideoLoadPhase.buffering) {
          _hasLoaded = true;
          _loadTimeout?.cancel();
        } else if (next == VideoLoadPhase.failed) {
          _loadTimeout?.cancel();
        }
        if (next != _phase) {
          setState(() => _phase = next);
        }
      },
      onError: (Object _) {
        if (!mounted || generation != _generation) return;
        _loadTimeout?.cancel();
        setState(() => _phase = VideoLoadPhase.failed);
      },
    );
    // Do not leave a user staring at an endless spinner on broken embeds,
    // blocked videos or an offline connection.
    _loadTimeout = Timer(const Duration(seconds: 25), () {
      if (!mounted || generation != _generation || _hasLoaded) return;
      setState(() => _phase = VideoLoadPhase.failed);
    });
  }

  void _retry() {
    _startPlayer();
    setState(() {});
  }

  @override
  void dispose() {
    ++_generation;
    _loadTimeout?.cancel();
    _statusSubscription?.cancel();
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
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            YoutubePlayer(
              key: ValueKey(controller),
              controller: controller,
              aspectRatio: 16 / 9,
            ),
            if (_phase == VideoLoadPhase.loading)
              const SukunVideoLoadingOverlay(),
            if (_phase == VideoLoadPhase.failed)
              _SukunVideoErrorOverlay(onRetry: _retry),
            // Once video has appeared, preserve the official player controls.
            // A small non-interactive indicator handles later buffering.
            if (_phase == VideoLoadPhase.buffering)
              const Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: _SukunVideoBufferingBadge(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Branded progress screen visible until YouTube confirms it can play.
/// The official player runs underneath, without a white blank frame.
class SukunVideoLoadingOverlay extends StatelessWidget {
  const SukunVideoLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SukunColors.nightNavy,
    child: Semantics(
      label: 'ভিডিও লোড হচ্ছে',
      liveRegion: true,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: SukunColors.sukunBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ভিডিও লোড হচ্ছে…',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'অনুগ্রহ করে একটু অপেক্ষা করুন',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SukunColors.mist,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: SukunColors.sukunBlue,
              backgroundColor: SukunColors.navySoft,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SukunVideoBufferingBadge extends StatelessWidget {
  const _SukunVideoBufferingBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SukunColors.nightNavy.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 13,
            width: 13,
            child: CircularProgressIndicator(
              color: SukunColors.sukunBlue,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'বাফারিং…',
            style: TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _SukunVideoErrorOverlay extends StatelessWidget {
  const _SukunVideoErrorOverlay({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SukunColors.nightNavy,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: SukunColors.mist,
              size: 26,
            ),
            const SizedBox(height: 6),
            const Text(
              'ভিডিও লোড করা যাচ্ছে না',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'সংযোগ পরীক্ষা করে আবার চেষ্টা করুন',
              style: TextStyle(
                color: SukunColors.mist,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('আবার চেষ্টা করুন'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: SukunColors.mist),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
