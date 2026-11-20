import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_glass.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// Keep the player constrained to its *content height*. A Positioned widget
/// anchored only by bottom/left/right gives its child almost the full screen
/// height; a default Center expands to that height and can cover the app with
/// a giant invisible/grey overlay around the small audio controls.
class AudioDockPositioner extends StatelessWidget {
  const AudioDockPositioner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Bottom navigation is visible at desktop widths too. Reserve one
    // consistent clearance for its safe area and interactive controls.
    final bottom =
        MediaQuery.paddingOf(context).bottom +
        SukunBottomNavigation.audioDockClearance;
    return Positioned(
      bottom: bottom,
      left: 12,
      right: 12,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: child,
        ),
      ),
    );
  }
}

/// Mounted above the router so playback survives navigation (including when
/// the original audio/ayah screen is disposed). Stays above mobile bottom nav.
class GlobalAudioDock extends ConsumerStatefulWidget {
  const GlobalAudioDock({super.key});

  @override
  ConsumerState<GlobalAudioDock> createState() => _GlobalAudioDockState();
}

class _GlobalAudioDockState extends ConsumerState<GlobalAudioDock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(audioPlaybackControllerProvider);
    // Do not keep playing private patient audio after switching accounts.
    ref.listen(appSessionProvider, (previous, next) {
      final oldUser = previous?.value?.userId;
      final newUser = next.value?.userId;
      if (oldUser != null && oldUser != newUser) {
        unawaited(controller.stopAndClear());
      }
    });
    // When typing, avoid placing the player over fields or the soft keyboard.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final fullPlayerOpen = ref.watch(fullAudioPlayerOpenProvider);
    final router = ref.read(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        // The route may be a nested playlist page above /my-media.
        // Suppress the floating dock for every focused full player.
        if (fullPlayerOpen) {
          return const SizedBox.shrink();
        }
        return AudioDockPositioner(
          child: TooltipVisibility(
            visible: false,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                if (!controller.hasSelection) return const SizedBox.shrink();
                return StreamBuilder<Duration>(
                  stream: controller.player.positionStream,
                  initialData: controller.player.position,
                  builder: (context, snapshot) {
                    final player = controller.player;
                    final playing = player.playing;
                    final isSequence = controller.isQuranSequence;
                    return AudioDockCard(
                      title: controller.currentTitle ?? 'অডিও',
                      verseLabel: controller.currentVerseKey == null
                          ? null
                          : (isSequence
                                ? '${controller.currentVerseKey} · '
                                      '${controller.currentVerseIndex + 1}/'
                                      '${controller.quranVerseCount}'
                                : controller.currentVerseKey),
                      playing: playing,
                      isSequence: isSequence,
                      position: snapshot.data ?? Duration.zero,
                      duration: player.duration ?? Duration.zero,
                      speed: player.speed,
                      expanded: _expanded,
                      onToggleExpanded: () =>
                          setState(() => _expanded = !_expanded),
                      onPlayPause: playing
                          ? () => unawaited(controller.pause())
                          : controller.resumeCurrent,
                      onSeek: (target) => unawaited(controller.seek(target)),
                      onPrevious: () => unawaited(controller.previous()),
                      onNext: () => unawaited(controller.next()),
                      onSpeed: () => unawaited(
                        controller.setSpeed(
                          nextAudioPlaybackSpeed(player.speed),
                        ),
                      ),
                      onClose: () => unawaited(controller.stopAndClear()),
                      onOpenLibrary: () =>
                          ref.read(appRouterProvider).push('/my-media'),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The redesigned mini player: a slim single-line bar by default with a
/// hairline progress track, which unfolds into a calm control panel with a
/// real seek bar, skip/seek buttons and a speed chip.
class AudioDockCard extends StatelessWidget {
  const AudioDockCard({
    super.key,
    required this.title,
    required this.playing,
    required this.position,
    required this.duration,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onPlayPause,
    required this.onSeek,
    required this.onClose,
    this.verseLabel,
    this.isSequence = false,
    this.speed = 1.0,
    this.onPrevious,
    this.onNext,
    this.onSpeed,
    this.onOpenLibrary,
  });

  final String title;

  /// Qur'an verse label (e.g. "2:255 · 3/7"); null for ordinary audio.
  final String? verseLabel;
  final bool playing;
  final bool isSequence;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onSpeed;
  final VoidCallback? onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 380;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final subtitle =
        verseLabel ??
        (duration > Duration.zero
            ? '${formatAudioDockTime(position)} / '
                  '${formatAudioDockTime(duration)}'
            : (playing ? 'শুনছেন' : 'বিরতিতে'));

    void seekBy(int seconds) =>
        onSeek(audioDockClampedSeekTarget(position, duration, seconds));

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: expanded ? 'কন্ট্রোল বন্ধ' : 'আরও কন্ট্রোল',
              child: InkWell(
                key: const Key('audio-dock-toggle'),
                borderRadius: BorderRadius.circular(14),
                onTap: onToggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: [
                      _AudioDockArtwork(playing: playing),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.25,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!expanded)
            AudioDockPrimaryAction(
              label: playing ? 'বিরতি' : 'চালু করুন',
              playing: playing,
              size: 44,
              onPressed: onPlayPause,
            ),
          AudioDockIconAction(
            label: expanded ? 'কন্ট্রোল বন্ধ' : 'আরও কন্ট্রোল',
            icon: expanded
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            color: scheme.onSurfaceVariant,
            onPressed: onToggleExpanded,
          ),
          AudioDockIconAction(
            label: 'অডিও বন্ধ করুন',
            icon: Icons.close_rounded,
            iconSize: 19,
            color: scheme.onSurfaceVariant,
            onPressed: onClose,
          ),
        ],
      ),
    );

    final panel = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AudioDockSeekSlider(
            duration: duration,
            position: position,
            onSeek: onSeek,
          ),
          Row(
            children: [
              _AudioDockTime(formatAudioDockTime(position)),
              const Spacer(),
              _AudioDockTime(formatAudioDockTime(duration)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _AudioDockSpeedChip(speed: speed, onPressed: onSpeed),
              const Spacer(),
              AudioDockIconAction(
                label: isSequence ? 'আগের আয়াত' : '১০ সেকেন্ড পেছনে',
                icon: isSequence
                    ? Icons.skip_previous_rounded
                    : Icons.replay_10_rounded,
                iconSize: 26,
                color: scheme.onSurface,
                onPressed: isSequence ? onPrevious : () => seekBy(-10),
              ),
              const SizedBox(width: 6),
              AudioDockPrimaryAction(
                label: playing ? 'বিরতি' : 'চালু করুন',
                playing: playing,
                size: 52,
                onPressed: onPlayPause,
              ),
              const SizedBox(width: 6),
              AudioDockIconAction(
                label: isSequence ? 'পরের আয়াত' : '১০ সেকেন্ড সামনে',
                icon: isSequence
                    ? Icons.skip_next_rounded
                    : Icons.forward_10_rounded,
                iconSize: 26,
                color: scheme.onSurface,
                onPressed: isSequence ? onNext : () => seekBy(10),
              ),
              const Spacer(),
              if (compact || onOpenLibrary == null)
                const SizedBox(width: 48)
              else
                AudioDockIconAction(
                  label: 'আমার প্লেলিস্ট ও ডাউনলোড',
                  icon: Icons.queue_music_rounded,
                  color: scheme.onSurfaceVariant,
                  onPressed: onOpenLibrary,
                ),
            ],
          ),
        ],
      ),
    );

    // The shadow sits outside the clipped card so it never shows through.
    return DecoratedBox(
      key: const Key('global-audio-dock'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SukunRadius.tile),
        boxShadow: [
          BoxShadow(
            color: SukunColors.nightNavy.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SukunRadius.tile),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded ? panel : const SizedBox(width: double.infinity),
            ),
            if (!expanded)
              SizedBox(
                height: 3,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    key: const Key('audio-dock-progress'),
                    widthFactor: progress,
                    heightFactor: 1,
                    child: ColoredBox(color: SukunColors.sukunBlue),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudioDockArtwork extends StatelessWidget {
  const _AudioDockArtwork({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(SukunRadius.control),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [SukunColors.sukunBlue, SukunColors.deepTide],
      ),
    ),
    child: Icon(
      playing ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
      color: Colors.white,
      size: 22,
    ),
  );
}

class _AudioDockTime extends StatelessWidget {
  const _AudioDockTime(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _AudioDockSpeedChip extends StatelessWidget {
  const _AudioDockSpeedChip({required this.speed, required this.onPressed});

  final double speed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '$speed×';
    return Semantics(
      label: 'প্লেব্যাক গতি পরিবর্তন',
      button: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 48,
          child: Center(
            child: SukunGlass(
              borderRadius: BorderRadius.circular(SukunRadius.chip),
              tone: SukunGlassTone.surface,
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(SukunRadius.chip),
                child: InkWell(
                  key: const Key('audio-dock-speed'),
                  borderRadius: BorderRadius.circular(SukunRadius.chip),
                  onTap: onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: SukunColors.deepTide,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatAudioDockTime(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = seconds ~/ 60;
  final secondsPart = (seconds % 60).toString().padLeft(2, '0');
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:$secondsPart';
  }
  return '$minutes:$secondsPart';
}

Duration audioDockClampedSeekTarget(
  Duration position,
  Duration duration,
  int offsetSeconds,
) {
  final target = position.inMilliseconds + offsetSeconds * 1000;
  final end = duration.inMilliseconds;
  return Duration(milliseconds: target.clamp(0, end < 0 ? 0 : end).toInt());
}

/// The primary action stays visible and easy to hit without a tooltip layer.
class AudioDockPrimaryAction extends StatelessWidget {
  const AudioDockPrimaryAction({
    required this.label,
    required this.playing,
    required this.onPressed,
    this.size = 44,
    super.key,
  });

  final String label;
  final bool playing;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: IconButton.filled(
          onPressed: onPressed,
          icon: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: size * 0.55,
          ),
          style: IconButton.styleFrom(
            backgroundColor: SukunColors.sukunBlue,
            foregroundColor: Colors.white,
            minimumSize: Size(size, size),
            fixedSize: Size(size, size),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

/// A compact, keyboard-accessible speed action with no floating popup menu.
/// Cycling presets avoids creating a second full-screen overlay on Flutter Web.
double nextAudioPlaybackSpeed(double current) {
  const presets = <double>[0.75, 1.0, 1.25, 1.5, 2.0];
  final index = presets.indexWhere((speed) => (speed - current).abs() < 0.01);
  return presets[(index + 1) % presets.length];
}

/// The global dock must not create a visual Tooltip/OverlayEntry on mouse
/// hover. Keep the button available to screen readers and keyboard users.
class AudioDockIconAction extends StatelessWidget {
  const AudioDockIconAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.iconSize,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    enabled: onPressed != null,
    child: ExcludeSemantics(
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: color,
        iconSize: iconSize,
      ),
    ),
  );
}

/// A custom seek bar instead of Material [Slider]. The Slider rendered as a
/// tall grey block inside the floating dock on Flutter Web; this bar always
/// has a tight, known height and supports both tap-to-seek and dragging.
class AudioDockSeekSlider extends StatefulWidget {
  const AudioDockSeekSlider({
    required this.duration,
    required this.position,
    required this.onSeek,
    super.key,
  });

  static const double height = 28;

  final Duration duration;
  final Duration position;
  final ValueChanged<Duration> onSeek;

  @override
  State<AudioDockSeekSlider> createState() => _AudioDockSeekSliderState();
}

class _AudioDockSeekSliderState extends State<AudioDockSeekSlider> {
  double? _dragFraction;

  double get _fraction {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _update(double dx, double width, {required bool commit}) {
    if (widget.duration.inMilliseconds <= 0 || width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = commit ? null : fraction);
    if (commit) {
      widget.onSeek(
        Duration(
          milliseconds: (fraction * widget.duration.inMilliseconds).round(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.duration.inMilliseconds > 0;
    final fraction = _dragFraction ?? _fraction;
    return Semantics(
      slider: true,
      label: 'অডিওর অবস্থান',
      value: '${(fraction * 100).round()}%',
      child: SizedBox(
        key: const Key('audio-dock-seek'),
        height: AudioDockSeekSlider.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled
                  ? (d) => _update(d.localPosition.dx, width, commit: true)
                  : null,
              onHorizontalDragUpdate: enabled
                  ? (d) => _update(d.localPosition.dx, width, commit: false)
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) {
                      final f = _dragFraction;
                      if (f != null) _update(f * width, width, commit: true);
                    }
                  : null,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: SukunColors.sukunBlue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 4,
                    width: width * fraction,
                    decoration: BoxDecoration(
                      color: enabled
                          ? SukunColors.sukunBlue
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  if (enabled)
                    Positioned(
                      left: (width * fraction - 7).clamp(
                        0.0,
                        width > 14 ? width - 14 : 0.0,
                      ),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SukunColors.sukunBlue,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
