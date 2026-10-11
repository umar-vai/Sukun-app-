import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/presentation/sukun_audio_visualizer.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({
    required this.resource,
    this.loadResource,
    super.key,
  });

  final LinkedResource resource;

  /// Test seam for broken links and retry without loading real patient media.
  final Future<void> Function(LinkedResource)? loadResource;

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  late Future<bool> _loadFuture;

  // Convert a source failure into UI state before a retry can rebuild.
  // A synchronously failing Future must never escape into the widget zone.
  Future<bool> _loadAudio() async {
    try {
      final loader =
          widget.loadResource ?? ref.read(audioPlaybackControllerProvider).load;
      await loader(widget.resource);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAudio();
  }

  @override
  void didUpdateWidget(covariant AudioPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (audioResourceNeedsReload(oldWidget.resource, widget.resource)) {
      _loadFuture = _loadAudio();
    }
  }

  void _retry() {
    setState(() {
      _loadFuture = _loadAudio();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অডিও শুনুন')),
      body: FutureBuilder<bool>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'অডিও চালু হচ্ছে…');
          }
          if (snapshot.data != true) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: _retry,
            );
          }
          return _PlayerBody(resource: widget.resource);
        },
      ),
    );
  }
}

class _PlayerBody extends ConsumerStatefulWidget {
  const _PlayerBody({required this.resource});

  final LinkedResource resource;

  @override
  ConsumerState<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends ConsumerState<_PlayerBody> {
  double? _draggingMilliseconds;
  bool _animationEnabled = true;

  Uri? get _artwork {
    final raw = widget.resource.thumbnailUrl;
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri?.scheme != 'https' || uri?.host.isNotEmpty != true) return null;
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(audioPlaybackControllerProvider);
    final player = controller.player;
    final title = widget.resource.titleBn?.trim().isNotEmpty == true
        ? widget.resource.titleBn!
        : widget.resource.title;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    initialData: player.playerState,
                    builder: (context, stateSnapshot) {
                      final state = stateSnapshot.data;
                      final isBuffering =
                          state?.processingState == ProcessingState.loading ||
                          state?.processingState == ProcessingState.buffering;
                      final playing =
                          state?.playing == true &&
                          !isBuffering &&
                          state?.processingState != ProcessingState.completed;
                      return StreamBuilder<Duration>(
                        stream: player.positionStream,
                        initialData: player.position,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AudioHero(
                                artwork: _artwork,
                                audioUrl: resolveResourceMedia(widget.resource)?.uri,
                                playbackSpeed: player.speed,
                                playing: playing,
                                buffering: isBuffering,
                                position: position,
                                animationEnabled: _animationEnabled,
                                onToggleAnimation: () => setState(() {
                                  _animationEnabled = !_animationEnabled;
                                }),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (widget.resource.titleBn?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 5),
                                Text(
                                  widget.resource.title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 22),
                              SukunSurface(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  22,
                                  20,
                                  24,
                                ),
                                child: Column(
                                  children: [
                                    StreamBuilder<Duration?>(
                                      stream: player.durationStream,
                                      initialData: player.duration,
                                      builder: (context, durationSnapshot) {
                                        final duration =
                                            durationSnapshot.data ??
                                            Duration.zero;
                                        final clamped = _boundedPosition(
                                          position,
                                          duration,
                                        );
                                        final current =
                                            _draggingMilliseconds == null
                                            ? clamped
                                            : Duration(
                                                milliseconds:
                                                    _draggingMilliseconds!
                                                        .round(),
                                              );
                                        final maxMs = duration.inMilliseconds
                                            .toDouble();
                                        return Column(
                                          children: [
                                            SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                    trackHeight: 5,
                                                    thumbShape:
                                                        const RoundSliderThumbShape(
                                                          enabledThumbRadius: 8,
                                                        ),
                                                  ),
                                              child: Slider(
                                                key: const ValueKey(
                                                  'audio-progress-slider',
                                                ),
                                                semanticFormatterCallback:
                                                    (value) => _durationLabel(
                                                      Duration(
                                                        milliseconds: value
                                                            .round(),
                                                      ),
                                                    ),
                                                value: current.inMilliseconds
                                                    .toDouble()
                                                    .clamp(
                                                      0.0,
                                                      maxMs > 0 ? maxMs : 1.0,
                                                    )
                                                    .toDouble(),
                                                min: 0,
                                                max: maxMs > 0 ? maxMs : 1.0,
                                                onChanged: maxMs <= 0
                                                    ? null
                                                    : (value) => setState(() {
                                                        _draggingMilliseconds =
                                                            value;
                                                      }),
                                                onChangeEnd: maxMs <= 0
                                                    ? null
                                                    : (value) {
                                                        setState(() {
                                                          _draggingMilliseconds =
                                                              null;
                                                        });
                                                        _runPlaybackAction(
                                                          context,
                                                          () => controller.seek(
                                                            Duration(
                                                              milliseconds:
                                                                  value.round(),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    _durationLabel(current),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    duration > Duration.zero
                                                        ? '-${_durationLabel(duration - current)}'
                                                        : '--:--',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          tooltip: '১০ সেকেন্ড পেছনে যান',
                                          onPressed: () => _runPlaybackAction(
                                            context,
                                            () => controller.seek(
                                              audioSeekTarget(
                                                player.position,
                                                player.duration,
                                                -10,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.replay_10_rounded,
                                            size: 29,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 78,
                                          height: 78,
                                          child: isBuffering
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                )
                                              : IconButton.filled(
                                                  key: const ValueKey(
                                                    'audio-play-pause',
                                                  ),
                                                  iconSize: 45,
                                                  tooltip: playing
                                                      ? 'থামান'
                                                      : 'চালু করুন',
                                                  onPressed: () =>
                                                      _runPlaybackAction(
                                                        context,
                                                        playing
                                                            ? controller.pause
                                                            : controller.play,
                                                      ),
                                                  icon: Icon(
                                                    playing
                                                        ? Icons.pause_rounded
                                                        : Icons
                                                              .play_arrow_rounded,
                                                  ),
                                                ),
                                        ),
                                        IconButton(
                                          tooltip: '১০ সেকেন্ড সামনে যান',
                                          onPressed: () => _runPlaybackAction(
                                            context,
                                            () => controller.seek(
                                              audioSeekTarget(
                                                player.position,
                                                player.duration,
                                                10,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.forward_10_rounded,
                                            size: 29,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    const Divider(height: 1),
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.speed_rounded,
                                          color: SukunColors.deepTide,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'শোনার গতি',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        StreamBuilder<LoopMode>(
                                          stream: player.loopModeStream,
                                          initialData: player.loopMode,
                                          builder: (context, snapshot) {
                                            final repeating =
                                                snapshot.data == LoopMode.one;
                                            return IconButton(
                                              tooltip: repeating
                                                  ? 'পুনরাবৃত্তি বন্ধ করুন'
                                                  : 'একই অডিও আবার চালান',
                                              onPressed: () =>
                                                  _runPlaybackAction(
                                                    context,
                                                    controller.toggleRepeatOne,
                                                  ),
                                              icon: Icon(
                                                Icons.repeat_one_rounded,
                                                color: repeating
                                                    ? SukunColors.sukunBlue
                                                    : SukunColors.muted,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    StreamBuilder<double>(
                                      stream: player.speedStream,
                                      initialData: player.speed,
                                      builder: (context, speedSnapshot) {
                                        final selected =
                                            speedSnapshot.data ?? 1.0;
                                        return Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 7,
                                          runSpacing: 7,
                                          children: [
                                            for (final speed in const [
                                              0.75,
                                              1.0,
                                              1.25,
                                              1.5,
                                              2.0,
                                            ])
                                              ChoiceChip(
                                                label: Text('${speed}x'),
                                                selected: selected == speed,
                                                onSelected: (_) =>
                                                    _runPlaybackAction(
                                                      context,
                                                      () => controller.setSpeed(
                                                        speed,
                                                      ),
                                                    ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  if (widget.resource.rightsNote?.trim().isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 22),
                    SukunSurface(
                      tone: SukunSurfaceTone.soft,
                      showBorder: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'উৎস ও ব্যবহারের অনুমতি',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(widget.resource.rightsNote!),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const AudioPlaybackPlatformHint(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Relative seek target, clamped to known duration and the start of playback.
Duration audioSeekTarget(Duration position, Duration? duration, int seconds) {
  final target = position + Duration(seconds: seconds);
  if (target.isNegative) return Duration.zero;
  if (duration != null && duration > Duration.zero && target > duration) {
    return duration;
  }
  return target;
}

class _AudioHero extends StatelessWidget {
  const _AudioHero({
    required this.artwork,
    required this.audioUrl,
    required this.playbackSpeed,
    required this.playing,
    required this.buffering,
    required this.position,
    required this.animationEnabled,
    required this.onToggleAnimation,
  });

  final Uri? artwork;
  final Uri? audioUrl;
  final double playbackSpeed;
  final bool playing;
  final bool buffering;
  final Duration position;
  final bool animationEnabled;
  final VoidCallback onToggleAnimation;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          SukunColors.nightNavy,
          SukunColors.navySoft,
          SukunColors.deepTide,
        ],
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        children: [
          Row(
            children: [
              const AudioPlaybackPlatformBadge(),
              const Spacer(),
              IconButton(
                tooltip: animationEnabled
                    ? 'অ্যানিমেশন বন্ধ করুন'
                    : 'অ্যানিমেশন চালু করুন',
                onPressed: onToggleAnimation,
                icon: Icon(
                  animationEnabled
                      ? Icons.animation_rounded
                      : Icons.motion_photos_off_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: artwork == null
                ? const Icon(
                    Icons.headphones_rounded,
                    color: Colors.white,
                    size: 58,
                  )
                : Image.network(
                    artwork.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, trace) => const Icon(
                      Icons.headphones_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          SukunAudioVisualizer(
            playing: playing,
            position: position,
            audioUrl: audioUrl,
            playbackSpeed: playbackSpeed,
            animated: animationEnabled,
          ),
          const SizedBox(height: 4),
          Text(
            buffering
                ? 'অডিও লোড হচ্ছে…'
                : playing
                ? 'অডিও চলছে'
                : 'শোনার জন্য প্রস্তুত',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'সোর্স অনুমতি দিলে প্রকৃত শব্দের ফ্রিকোয়েন্সি দেখা যাবে',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFD1E6F3), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

/// Browsers have different media-session and background-playback policies
/// from Android/iOS. Avoid claiming lock-screen controls on Flutter Web.
class AudioPlaybackPlatformBadge extends StatelessWidget {
  const AudioPlaybackPlatformBadge({super.key});

  @override
  Widget build(BuildContext context) => SukunStatusPill(
    label: kIsWeb ? 'ব্রাউজারে অডিও' : 'পেছনেও চলবে',
    tone: SukunStatusTone.brand,
    icon: Icons.headphones_rounded,
  );
}

class AudioPlaybackPlatformHint extends StatelessWidget {
  const AudioPlaybackPlatformHint({super.key});

  @override
  Widget build(BuildContext context) => Text(
    kIsWeb
        ? 'ব্রাউজারে অডিও শুনুন। ট্যাব পরিবর্তন বা স্ক্রিন লক করলে অডিও চলা ব্রাউজারের নিয়মের ওপর নির্ভর করে।'
        : 'অন্য অ্যাপ খুললেও অডিও চলতে পারে। ফোনের লকস্ক্রিন থেকে চালু বা বন্ধ করতে পারবেন।',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

Future<void> _runPlaybackAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on AudioPlaybackException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('অডিও চালু করা যাচ্ছে না। আবার চেষ্টা করুন।')),
    );
  } on Exception {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('অডিওর অবস্থাটি বদলানো যায়নি। আবার চেষ্টা করুন।'),
      ),
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
