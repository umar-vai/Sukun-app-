import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
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
    final scheme = Theme.of(context).colorScheme;
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
                final player = controller.player;
                final playing = player.playing;
                final isSequence = controller.isQuranSequence;
                final verse = controller.currentVerseKey;
                final compact = MediaQuery.sizeOf(context).width < 380;
                final duration = player.duration ?? Duration.zero;
                final subtitle = verse == null
                    ? 'শুনছেন'
                    : (isSequence
                          ? verse +
                                ' · ' +
                                (controller.currentVerseIndex + 1).toString() +
                                '/' +
                                controller.quranVerseCount.toString()
                          : verse);
                return Material(
                  elevation: 6,
                  color: scheme.surface,
                  shadowColor: scheme.shadow.withValues(alpha: 0.16),
                  surfaceTintColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.65),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer.withValues(
                                    alpha: 0.65,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: scheme.primary,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      controller.currentTitle ?? 'অডিও',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!compact)
                                AudioDockIconAction(
                                  label: 'আমার প্লেলিস্ট ও ডাউনলোড',
                                  icon: Icons.queue_music_rounded,
                                  onPressed: () => ref
                                      .read(appRouterProvider)
                                      .push('/my-media'),
                                ),
                              AudioDockPrimaryAction(
                                label: playing ? 'বিরতি' : 'চালু করুন',
                                playing: playing,
                                onPressed: playing
                                    ? () => unawaited(controller.pause())
                                    : controller.resumeCurrent,
                              ),
                              AudioDockIconAction(
                                label: _expanded
                                    ? 'কন্ট্রোল বন্ধ'
                                    : 'আরও কন্ট্রোল',
                                icon: _expanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_up_rounded,
                                onPressed: () =>
                                    setState(() => _expanded = !_expanded),
                              ),
                              AudioDockIconAction(
                                label: 'অডিও বন্ধ করুন',
                                icon: Icons.close_rounded,
                                iconSize: 19,
                                onPressed: () =>
                                    unawaited(controller.stopAndClear()),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _expanded
                              ? StreamBuilder<Duration>(
                                  stream: player.positionStream,
                                  initialData: player.position,
                                  builder: (context, snapshot) {
                                    final position =
                                        snapshot.data ?? Duration.zero;
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        10,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AudioDockSeekSlider(
                                            duration: duration,
                                            position: position,
                                            onSeek: (target) => unawaited(
                                              controller.seek(target),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  formatAudioDockTime(position),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  formatAudioDockTime(duration),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              AudioDockIconAction(
                                                label: isSequence
                                                    ? 'আগের আয়াত'
                                                    : '১০ সেকেন্ড পেছনে',
                                                icon: isSequence
                                                    ? Icons
                                                          .skip_previous_rounded
                                                    : Icons.replay_10_rounded,
                                                onPressed: () => unawaited(
                                                  isSequence
                                                      ? controller.previous()
                                                      : controller.seek(
                                                          audioDockClampedSeekTarget(
                                                            position,
                                                            duration,
                                                            -10,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              Semantics(
                                                label: 'প্লেব্যাক গতি পরিবর্তন',
                                                button: true,
                                                child: ExcludeSemantics(
                                                  child: TextButton(
                                                    onPressed: () => unawaited(
                                                      controller.setSpeed(
                                                        nextAudioPlaybackSpeed(
                                                          player.speed,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      player.speed.toString() +
                                                          '×',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: scheme.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              AudioDockIconAction(
                                                label: isSequence
                                                    ? 'পরের আয়াত'
                                                    : '১০ সেকেন্ড সামনে',
                                                icon: isSequence
                                                    ? Icons.skip_next_rounded
                                                    : Icons.forward_10_rounded,
                                                onPressed: () => unawaited(
                                                  isSequence
                                                      ? controller.next()
                                                      : controller.seek(
                                                          audioDockClampedSeekTarget(
                                                            position,
                                                            duration,
                                                            10,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (!_expanded)
                          StreamBuilder<Duration>(
                            stream: player.positionStream,
                            initialData: player.position,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              return LinearProgressIndicator(
                                value: duration.inMilliseconds <= 0
                                    ? 0
                                    : (position.inMilliseconds /
                                              duration.inMilliseconds)
                                          .clamp(0.0, 1.0),
                                minHeight: 2,
                                color: scheme.primary,
                                backgroundColor: scheme.primary.withValues(
                                  alpha: 0.10,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

String formatAudioDockTime(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = seconds ~/ 60;
  final secondsPart = (seconds % 60).toString().padLeft(2, '0');
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    return hours.toString() +
        ':' +
        (minutes % 60).toString().padLeft(2, '0') +
        ':' +
        secondsPart;
  }
  return minutes.toString() + ':' + secondsPart;
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
    super.key,
  });

  final String label;
  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: IconButton.filled(
          onPressed: onPressed,
          icon: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 24,
          ),
          style: IconButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            minimumSize: const Size(44, 44),
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

/* The parent floating dock is in a Positioned/Align above the route. A raw
 * Flutter Slider uses all available vertical space when handed loose,
 * bounded-height constraints, rendering as a page-tall blank grey region.
 * Give the real slider a tight height, independent of desktop viewport size.
 */
class AudioDockSeekSlider extends StatelessWidget {
  const AudioDockSeekSlider({
    required this.duration,
    required this.position,
    required this.onSeek,
    super.key,
  });

  final Duration duration;
  final Duration position;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          trackShape: const RoundedRectSliderTrackShape(),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: scheme.primary,
          inactiveTrackColor: scheme.outlineVariant,
          thumbColor: scheme.primary,
          overlayColor: scheme.primary.withValues(alpha: 0.12),
        ),
        child: Slider(
          value: max <= 0 ? 0 : value,
          max: max <= 0 ? 1 : max,
          onChanged: max <= 0
              ? null
              : (v) => onSeek(Duration(milliseconds: v.round())),
        ),
      ),
    );
  }
}
