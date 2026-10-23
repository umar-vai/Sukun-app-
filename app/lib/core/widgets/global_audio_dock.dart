import 'dart:async';

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
        final path = router.routeInformationProvider.value.uri.path;
        // A resource detail screen already has a full player. Never overlay
        // that screen's transport controls with the global mini player.
        final segments = path.split('/');
        final onResourceDetail =
            (segments.length == 3 && segments[1] == 'resources') ||
            (segments.length == 4 &&
                segments[1] == 'patient' &&
                segments[2] == 'resources');
        if (fullPlayerOpen && onResourceDetail) {
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
            return Material(
              elevation: 12,
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value:
                          player.duration == null ||
                              player.duration!.inMilliseconds == 0
                          ? null
                          : (player.position.inMilliseconds /
                                    player.duration!.inMilliseconds)
                                .clamp(0, 1),
                      minHeight: 3,
                      color: scheme.primary,
                      backgroundColor: scheme.primaryContainer,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                      child: Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.currentTitle ?? 'অডিও',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  verse == null
                                      ? 'শুনছেন'
                                      : (isSequence
                                            ? '$verse · ${controller.currentVerseIndex + 1}/${controller.quranVerseCount}'
                                            : verse),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          AudioDockIconAction(
                            label: 'আমার প্লেলিস্ট ও ডাউনলোড',
                            icon: Icons.library_music_outlined,
                            onPressed: () =>
                                ref.read(appRouterProvider).push('/my-media'),
                          ),
                          AudioDockIconAction(
                            label: playing ? 'বিরতি' : 'চালু করুন',
                            onPressed: playing
                                ? () => unawaited(controller.pause())
                                : controller.resumeCurrent,
                            icon: playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: scheme.primary,
                            iconSize: 34,
                          ),
                          AudioDockIconAction(
                            label: _expanded ? 'কন্ট্রোল বন্ধ' : 'আরও কন্ট্রোল',
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                            icon: _expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
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
                    if (_expanded)
                      StreamBuilder<Duration>(
                        stream: player.positionStream,
                        initialData: player.position,
                        builder: (context, snapshot) {
                          final duration = player.duration ?? Duration.zero;
                          final position = snapshot.data ?? Duration.zero;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AudioDockSeekSlider(
                                  duration: duration,
                                  position: position,
                                  onSeek: (target) =>
                                      unawaited(controller.seek(target)),
                                ),
                                Row(
                                  children: [
                                    Text(_format(position)),
                                    const Spacer(),
                                    AudioDockIconAction(
                                      label: isSequence
                                          ? 'আগের আয়াত'
                                          : '১০ সেকেন্ড পেছনে',
                                      onPressed: () => unawaited(
                                        isSequence
                                            ? controller.previous()
                                            : controller.seek(
                                                position -
                                                    const Duration(seconds: 10),
                                              ),
                                      ),
                                      icon: Icons.skip_previous_rounded,
                                    ),
                                    TextButton(
                                      onPressed: () => unawaited(
                                        controller.setSpeed(
                                          nextAudioPlaybackSpeed(player.speed),
                                        ),
                                      ),
                                      child: Text('${player.speed}×'),
                                    ),
                                    AudioDockIconAction(
                                      label: isSequence
                                          ? 'পরের আয়াত'
                                          : '১০ সেকেন্ড সামনে',
                                      onPressed: () => unawaited(
                                        isSequence
                                            ? controller.next()
                                            : controller.seek(
                                                position +
                                                    const Duration(seconds: 10),
                                              ),
                                      ),
                                      icon: Icons.skip_next_rounded,
                                    ),
                                    const Spacer(),
                                    Text(_format(duration)),
                                  ],
                                ),
                              ],
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

  String _format(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
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
    return SizedBox(
      height: 40,
      child: Slider(
        value: max <= 0 ? 0 : value,
        max: max <= 0 ? 1 : max,
        onChanged: max <= 0
            ? null
            : (v) => onSeek(Duration(milliseconds: v.round())),
      ),
    );
  }
}
