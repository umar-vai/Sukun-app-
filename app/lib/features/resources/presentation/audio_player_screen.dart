import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({required this.resource, super.key});

  final LinkedResource resource;

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = ref
        .read(audioPlaybackControllerProvider)
        .load(widget.resource);
  }

  void _retry() {
    setState(() {
      _loadFuture = ref
          .read(audioPlaybackControllerProvider)
          .load(widget.resource);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio player')),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Preparing audio');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: _retry,
            );
          }
          return _PlayerBody(resource: widget.resource);
        },
      ),
    );
  }
}

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({required this.resource});

  final LinkedResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(audioPlaybackControllerProvider);
    final player = controller.player;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: SukunColors.mist,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              size: 86,
              color: SukunColors.deepTide,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            resource.titleBn?.trim().isNotEmpty == true
                ? resource.titleBn!
                : resource.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (resource.titleBn?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              resource.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 28),
          StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = _boundedPosition(
                    positionSnapshot.data ?? Duration.zero,
                    duration,
                  );
                  return Column(
                    children: [
                      Slider(
                        value: position.inMilliseconds.toDouble(),
                        max: duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1,
                        onChanged: duration == Duration.zero
                            ? null
                            : (value) => _runPlaybackAction(
                                context,
                                () => controller.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_durationLabel(position)),
                            Text(_durationLabel(duration)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Back 10 seconds',
                onPressed: () => _runPlaybackAction(
                  context,
                  () => controller.seek(
                    player.position - const Duration(seconds: 10),
                  ),
                ),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: 18),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final loading =
                      state?.processingState == ProcessingState.loading ||
                      state?.processingState == ProcessingState.buffering;
                  if (loading) {
                    return const SizedBox.square(
                      dimension: 64,
                      child: CircularProgressIndicator(),
                    );
                  }
                  final playing = state?.playing == true;
                  return IconButton.filled(
                    iconSize: 38,
                    tooltip: playing ? 'Pause' : 'Play',
                    onPressed: () => _runPlaybackAction(
                      context,
                      playing ? controller.pause : controller.play,
                    ),
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),
              IconButton.filledTonal(
                tooltip: 'Forward 10 seconds',
                onPressed: () => _runPlaybackAction(
                  context,
                  () => controller.seek(
                    player.position + const Duration(seconds: 10),
                  ),
                ),
                icon: const Icon(Icons.forward_10_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<double>(
            stream: player.speedStream,
            initialData: player.speed,
            builder: (context, snapshot) => Center(
              child: MenuAnchor(
                menuChildren: [
                  for (final speed in const [0.75, 1.0, 1.25, 1.5, 2.0])
                    MenuItemButton(
                      onPressed: () => _runPlaybackAction(
                        context,
                        () => controller.setSpeed(speed),
                      ),
                      child: Text('${speed}x'),
                    ),
                ],
                builder: (context, menuController, child) =>
                    OutlinedButton.icon(
                      onPressed: () => menuController.isOpen
                          ? menuController.close()
                          : menuController.open(),
                      icon: const Icon(Icons.speed_rounded),
                      label: Text('${snapshot.data ?? 1.0}x speed'),
                    ),
              ),
            ),
          ),
          if (resource.rightsNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 28),
            Text(
              'Rights & source',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(resource.rightsNote!),
          ],
          const SizedBox(height: 18),
          Text(
            'Playback continues in the background. Use the lock-screen controls to pause, resume, or seek.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Future<void> _runPlaybackAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on AudioPlaybackException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
  } on Exception {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playback could not be updated.')),
    );
  }
}

Duration _boundedPosition(Duration position, Duration duration) {
  if (position.isNegative) return Duration.zero;
  if (duration > Duration.zero && position > duration) return duration;
  return position;
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  return hours > 0
      ? '$hours:$minutes:$seconds'
      : '${duration.inMinutes}:$seconds';
}
