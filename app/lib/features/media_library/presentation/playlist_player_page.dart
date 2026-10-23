import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';

/// The real playlist player shared by online and offline saved audio.
class PlaylistPlayerPage extends ConsumerStatefulWidget {
  const PlaylistPlayerPage({super.key});

  @override
  ConsumerState<PlaylistPlayerPage> createState() => _PlaylistPlayerPageState();
}

class _PlaylistPlayerPageState extends ConsumerState<PlaylistPlayerPage> {
  late final void Function(bool) _setFullPlayerOpen;

  @override
  void initState() {
    super.initState();
    final state = ref.read(fullAudioPlayerOpenProvider.notifier);
    _setFullPlayerOpen = (value) => state.state = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setFullPlayerOpen(true);
    });
  }

  @override
  void dispose() {
    _setFullPlayerOpen(false);
    super.dispose();
  }

  Future<void> _showRules(AudioPlaybackController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('প্লেলিস্টের নিয়ম',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('প্রতিটি অডিও সর্বোচ্চ ১৫ মিনিট শুনে পরেরটিতে যাবে। '
                    'নির্বাচিত সংখ্যক অডিও শেষে থামবে।'),
              ),
              for (final count in const <int>[0, 3, 4])
                ListTile(
                  key: ValueKey('playlist-rule-$count'),
                  title: Text(count == 0
                      ? 'স্বয়ংক্রিয় প্লেলিস্ট বন্ধ'
                      : 'প্রতি ১৫ মিনিটে $count অডিও'),
                  leading: Icon(count == 0
                      ? Icons.stop_circle_outlined
                      : Icons.queue_music_rounded),
                  trailing: controller.stopAfterTracks == count
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () {
                    try {
                      controller.setTimedPlaylist(count);
                      Navigator.of(sheetContext).pop();
                    } on StateError {
                      Navigator.of(sheetContext).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content:
                              Text('আগে একটি প্লেলিস্ট চালু করুন।')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(audioPlaybackControllerProvider);
    final player = controller.player;
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.playlistTitle ?? 'অডিও প্লেয়ার',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxHeight < 590;
            final gap = compact ? 8.0 : 13.0;
            return SingleChildScrollView(
              key: const ValueKey('playlist-scroll-fallback'),
              padding: EdgeInsets.fromLTRB(18, compact ? 8 : 14, 18, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => Column(
                      key: const ValueKey('playlist-full-player'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PlaylistArt(
                          url: controller.resource?.thumbnailUrl,
                          height: playlistCoverHeight(
                              viewport.maxWidth, viewport.maxHeight),
                        ),
                        SizedBox(height: gap),
                        Text(controller.currentTitle ?? 'অডিও',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'অডিও ${controller.playlistIndex + 1} / ${controller.playlistLength}',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: gap),
                        StreamBuilder<Duration>(
                          stream: player.positionStream,
                          initialData: player.position,
                          builder: (context, snapshot) {
                            final elapsed = snapshot.data ?? Duration.zero;
                            final total = player.duration ?? Duration.zero;
                            final pos = total > Duration.zero && elapsed > total
                                ? total : elapsed;
                            final maxMs = total.inMilliseconds;
                            return Column(children: [
                              Slider(
                                key: const ValueKey('playlist-progress'),
                                value: maxMs <= 0 ? 0.0 :
                                    (pos.inMilliseconds / maxMs)
                                        .clamp(0.0, 1.0).toDouble(),
                                onChanged: maxMs <= 0 ? null : (value) =>
                                    unawaited(controller.seek(Duration(
                                        milliseconds: (value * maxMs).round()))),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(playlistDurationLabel(pos)),
                                    Text(total == Duration.zero ? '--:--' :
                                        playlistDurationLabel(total)),
                                  ],
                                ),
                              ),
                            ]);
                          },
                        ),
                        SizedBox(height: gap),
                        StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          initialData: player.playerState,
                          builder: (context, _) {
                            final busy = player.processingState ==
                                    ProcessingState.loading ||
                                player.processingState ==
                                    ProcessingState.buffering;
                            return Row(
                              key: const ValueKey('playlist-transport'),
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  tooltip: 'আগের অডিও',
                                  onPressed: player.hasPrevious ?
                                      () => unawaited(controller.previous()) : null,
                                  icon: const Icon(Icons.skip_previous_rounded)),
                                IconButton(
                                  tooltip: '১০ সেকেন্ড পেছনে',
                                  onPressed: () => unawaited(controller.seek(
                                      playlistSeekTarget(player.position,
                                          player.duration, -10))),
                                  icon: const Icon(Icons.replay_10_rounded)),
                                SizedBox(
                                  width: 64, height: 64,
                                  child: busy
                                      ? const Center(child: CircularProgressIndicator())
                                      : IconButton.filled(
                                          key: const ValueKey('playlist-play-pause'),
                                          tooltip: player.playing ? 'বিরতি' : 'চালান',
                                          onPressed: player.playing
                                              ? () => unawaited(controller.pause())
                                              : controller.resumeCurrent,
                                          icon: Icon(player.playing
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded, size: 36)),
                                ),
                                IconButton(
                                  tooltip: '১০ সেকেন্ড সামনে',
                                  onPressed: () => unawaited(controller.seek(
                                      playlistSeekTarget(player.position,
                                          player.duration, 10))),
                                  icon: const Icon(Icons.forward_10_rounded)),
                                IconButton(
                                  tooltip: 'পরের অডিও',
                                  onPressed: player.hasNext ?
                                      () => unawaited(controller.next()) : null,
                                  icon: const Icon(Icons.skip_next_rounded)),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: gap),
                        Row(
                          key: const ValueKey('playlist-extra-tools'),
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            StreamBuilder<double>(
                              stream: player.speedStream,
                              initialData: player.speed,
                              builder: (context, snapshot) {
                                final speed = snapshot.data ?? 1.0;
                                return PopupMenuButton<double>(
                                  key: const ValueKey('playlist-speed'),
                                  tooltip: 'শোনার গতি',
                                  onSelected: (v) => unawaited(controller.setSpeed(v)),
                                  itemBuilder: (_) => [
                                    for (final v in const <double>[
                                      0.75, 1.0, 1.25, 1.5, 2.0,
                                    ])
                                      PopupMenuItem(value: v, child: Text('${v}x')),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text('${speed}x',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                );
                              },
                            ),
                            PopupMenuButton<int>(
                              key: const ValueKey('playlist-timer'),
                              tooltip: 'স্লিপ টাইমার',
                              icon: Icon(controller.sleepDeadline == null
                                  ? Icons.bedtime_outlined : Icons.bedtime_rounded),
                              onSelected: controller.setSleepTimer,
                              itemBuilder: (_) => [
                                for (final n in const [0, 5, 15, 30, 60])
                                  PopupMenuItem(
                                    value: n,
                                    child: Text(n == 0
                                        ? 'টাইমার বন্ধ' : '$n মিনিট পরে থামবে'),
                                  ),
                              ],
                            ),
                            StreamBuilder<LoopMode>(
                              stream: player.loopModeStream,
                              initialData: player.loopMode,
                              builder: (context, snapshot) {
                                final active = snapshot.data == LoopMode.one;
                                return IconButton(
                                  key: const ValueKey('playlist-repeat'),
                                  tooltip: active ? 'পুনরাবৃত্তি বন্ধ'
                                      : 'একই অডিও আবার চালান',
                                  onPressed: () => unawaited(
                                      controller.toggleRepeatOne()),
                                  icon: Icon(Icons.repeat_one_rounded,
                                      color: active ?
                                          Theme.of(context).colorScheme.primary : null),
                                );
                              },
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('playlist-rules'),
                              onPressed: () => _showRules(controller),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('নিয়ম'),
                            ),
                          ],
                        ),
                        if (controller.stopAfterTracks != 0) ...[
                          const SizedBox(height: 5),
                          Text(
                            'প্রতি ১৫ মিনিটে ${controller.stopAfterTracks} অডিও শেষে থামবে',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

double playlistCoverHeight(double width, double height) {
  final suggested = (height * 0.28).clamp(115.0, 200.0);
  return suggested.clamp(115.0, (width - 36).clamp(115.0, 200.0)).toDouble();
}

Duration playlistSeekTarget(Duration pos, Duration? duration, int seconds) {
  final target = pos + Duration(seconds: seconds);
  if (target.isNegative) return Duration.zero;
  if (duration != null && duration > Duration.zero && target > duration) {
    return duration;
  }
  return target;
}

String playlistDurationLabel(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}

class _PlaylistArt extends StatelessWidget {
  const _PlaylistArt({required this.url, required this.height});
  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    final hasArt = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D2B45), Color(0xFF0A70A8), Color(0xFF0F9BD7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(fit: StackFit.expand, children: [
            if (hasArt)
              Image.network(uri.toString(), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.headphones_rounded,
                          color: Colors.white, size: 66)))
            else
              const Center(child: Icon(Icons.headphones_rounded,
                  color: Colors.white, size: 66)),
            const Positioned(bottom: 12, left: 16,
                child: Icon(Icons.graphic_eq_rounded, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
