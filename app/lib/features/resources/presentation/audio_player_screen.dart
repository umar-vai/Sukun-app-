import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sukun_life/features/media_library/presentation/audio_library_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/presentation/sukun_static_waveform.dart';

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
  late final void Function(bool) _setFullPlayerVisible;

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
    final visibility = ref.read(fullAudioPlayerOpenProvider.notifier);
    _setFullPlayerVisible = (value) => visibility.state = value;
    _loadFuture = _loadAudio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setFullPlayerVisible(true);
      }
    });
  }

  @override
  void dispose() {
    _setFullPlayerVisible(false);
    super.dispose();
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
      appBar: AppBar(
        title: Text(
          widget.resource.titleBn?.trim().isNotEmpty == true
              ? widget.resource.titleBn!
              : widget.resource.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (ref.watch(appSessionProvider).value?.isAuthenticated == true)
            IconButton(
              onPressed: () => context.push(
                '/my-routines?resourceId=${Uri.encodeQueryComponent(widget.resource.id)}',
              ),
              tooltip: 'আমার রুটিনে যুক্ত করুন',
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          if (ref.watch(appSessionProvider).value?.isSuperAdmin == true)
            IconButton(
              onPressed: () =>
                  context.push('/admin/content/${widget.resource.id}/edit'),
              tooltip: 'অডিও সম্পাদনা করুন',
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
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
      child: LayoutBuilder(
        builder: (context, viewport) {
          // All core actions fit the first phone viewport. On tiny screens,
          // landscape and zoomed browsers, scrolling remains accessible.
          final compact = viewport.maxHeight < 590;
          final gap = compact ? 7.0 : 12.0;
          final coverHeight = audioCoverHeightForViewport(
            viewport.maxWidth,
            viewport.maxHeight,
          );
          return SingleChildScrollView(
            key: const ValueKey('audio-player-scroll-fallback'),
            padding: EdgeInsets.fromLTRB(
              16,
              compact ? 8 : 16,
              16,
              compact ? 8 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  initialData: player.playerState,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final buffering =
                        state?.processingState == ProcessingState.loading ||
                        state?.processingState == ProcessingState.buffering;
                    final playing =
                        state?.playing == true &&
                        !buffering &&
                        state?.processingState != ProcessingState.completed;
                    return StreamBuilder<Duration>(
                      stream: player.positionStream,
                      initialData: player.position,
                      builder: (context, positionSnapshot) {
                        final position = positionSnapshot.data ?? Duration.zero;
                        return Column(
                          key: const ValueKey('audio-player-first-viewport'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AudioHero(
                              artwork: _artwork,
                              playing: playing,
                              buffering: buffering,
                              height: coverHeight,
                            ),
                            SizedBox(height: gap),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (!compact &&
                                widget.resource.titleBn?.trim().isNotEmpty ==
                                    true) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.resource.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            SizedBox(height: gap),
                            _progressControls(context, controller, position),
                            SizedBox(height: gap),
                            _transportControls(
                              context,
                              controller,
                              playing: playing,
                              buffering: buffering,
                            ),
                            SizedBox(height: gap),
                            _secondaryControls(context, controller),
                            if (!compact) ...[
                              const SizedBox(height: 10),
                              const AudioPlaybackPlatformHint(),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _progressControls(
    BuildContext context,
    AudioPlaybackController controller,
    Duration position,
  ) {
    final player = controller.player;
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      initialData: player.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final clamped = _boundedPosition(position, duration);
        final current = _draggingMilliseconds == null
            ? clamped
            : Duration(milliseconds: _draggingMilliseconds!.round());
        final maxMs = duration.inMilliseconds.toDouble();
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                key: const ValueKey('audio-progress-slider'),
                semanticFormatterCallback: (value) =>
                    _durationLabel(Duration(milliseconds: value.round())),
                value: current.inMilliseconds
                    .toDouble()
                    .clamp(0.0, maxMs > 0 ? maxMs : 1.0)
                    .toDouble(),
                min: 0,
                max: maxMs > 0 ? maxMs : 1.0,
                onChanged: maxMs <= 0
                    ? null
                    : (value) => setState(() {
                        _draggingMilliseconds = value;
                      }),
                onChangeEnd: maxMs <= 0
                    ? null
                    : (value) {
                        setState(() {
                          _draggingMilliseconds = null;
                        });
                        _runPlaybackAction(
                          context,
                          () => controller.seek(
                            Duration(milliseconds: value.round()),
                          ),
                        );
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _durationLabel(current),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    duration > Duration.zero
                        ? _durationLabel(duration)
                        : '--:--',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _transportControls(
    BuildContext context,
    AudioPlaybackController controller, {
    required bool playing,
    required bool buffering,
  }) {
    final player = controller.player;
    final encoded = Uri.encodeQueryComponent(widget.resource.id);
    return Row(
      key: const ValueKey('audio-primary-actions'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          key: const ValueKey('audio-playlist-add'),
          tooltip: 'প্লেলিস্টে যোগ করুন',
          onPressed: () => context.push('/my-media?add=$encoded'),
          icon: const Icon(Icons.playlist_add_rounded),
        ),
        IconButton(
          tooltip: '১০ সেকেন্ড পেছনে যান',
          onPressed: () => _runPlaybackAction(
            context,
            () => controller.seek(
              audioSeekTarget(player.position, player.duration, -10),
            ),
          ),
          icon: const Icon(Icons.replay_10_rounded, size: 27),
        ),
        SizedBox(
          width: 68,
          height: 68,
          child: buffering
              ? const Center(child: CircularProgressIndicator())
              : IconButton.filled(
                  key: const ValueKey('audio-play-pause'),
                  iconSize: 39,
                  tooltip: playing ? 'থামান' : 'চালু করুন',
                  onPressed: () => _runPlaybackAction(
                    context,
                    playing
                        ? controller.pause
                        : () => controller.play(
                            expectedResource: widget.resource,
                          ),
                  ),
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
        ),
        IconButton(
          tooltip: '১০ সেকেন্ড সামনে যান',
          onPressed: () => _runPlaybackAction(
            context,
            () => controller.seek(
              audioSeekTarget(player.position, player.duration, 10),
            ),
          ),
          icon: const Icon(Icons.forward_10_rounded, size: 27),
        ),
        OfflineDownloadAction(
          key: const ValueKey('audio-download'),
          resourceId: widget.resource.id,
          iconOnly: true,
        ),
      ],
    );
  }

  Widget _secondaryControls(
    BuildContext context,
    AudioPlaybackController controller,
  ) {
    final player = controller.player;
    return Row(
      key: const ValueKey('audio-secondary-actions'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StreamBuilder<double>(
          stream: player.speedStream,
          initialData: player.speed,
          builder: (context, snapshot) {
            final speed = snapshot.data ?? 1.0;
            return PopupMenuButton<double>(
              key: const ValueKey('audio-speed-menu'),
              tooltip: 'শোনার গতি',
              onSelected: (value) =>
                  _runPlaybackAction(context, () => controller.setSpeed(value)),
              itemBuilder: (context) => [
                for (final preset in const <double>[0.75, 1.0, 1.25, 1.5, 2.0])
                  PopupMenuItem(value: preset, child: Text('${preset}x')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 15,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('শোনার গতি', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      '${speed}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: SukunColors.deepTide,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        PopupMenuButton<int>(
          key: const ValueKey('audio-sleep-timer'),
          tooltip: 'স্লিপ টাইমার',
          icon: Icon(
            Icons.bedtime_outlined,
            color: controller.sleepDeadline == null
                ? SukunColors.muted
                : SukunColors.sukunBlue,
          ),
          onSelected: controller.setSleepTimer,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0, child: Text('স্লিপ টাইমার বন্ধ')),
            PopupMenuItem(value: 5, child: Text('৫ মিনিট পরে থামুন')),
            PopupMenuItem(value: 15, child: Text('১৫ মিনিট পরে থামুন')),
            PopupMenuItem(value: 30, child: Text('৩০ মিনিট পরে থামুন')),
            PopupMenuItem(value: 60, child: Text('৬০ মিনিট পরে থামুন')),
          ],
        ),
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          initialData: player.loopMode,
          builder: (context, snapshot) {
            final repeating = snapshot.data == LoopMode.one;
            return IconButton(
              key: const ValueKey('audio-repeat-toggle'),
              tooltip: repeating
                  ? 'পুনরাবৃত্তি বন্ধ করুন'
                  : 'একই অডিও আবার চালান',
              onPressed: () =>
                  _runPlaybackAction(context, controller.toggleRepeatOne),
              icon: Icon(
                Icons.repeat_one_rounded,
                color: repeating ? SukunColors.sukunBlue : SukunColors.muted,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Cover scales to the available phone height instead of pushing playback
/// controls below the first visible viewport. Tiny screens may still scroll.
double audioCoverHeightForViewport(double width, double height) =>
    (height * 0.27)
        .clamp(108.0, 220.0)
        .toDouble()
        .clamp(108.0, (width - 32).clamp(108.0, 220.0).toDouble())
        .toDouble();

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
    required this.playing,
    required this.buffering,
    required this.height,
  });

  final Uri? artwork;
  final bool playing;
  final bool buffering;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SukunColors.nightNavy,
              SukunColors.navySoft,
              SukunColors.deepTide,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artwork != null)
              Image.network(
                artwork.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, trace) =>
                    const Center(child: SukunStaticWaveform()),
              )
            else
              const Center(child: SukunStaticWaveform()),
            const Positioned(
              top: 10,
              left: 10,
              child: AudioPlaybackPlatformBadge(),
            ),
            if (buffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (playing)
              const Positioned(
                bottom: 10,
                right: 12,
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
          ],
        ),
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
