import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';

/// Keep the player constrained to its *content height*. A Positioned widget
/// anchored only by bottom/left/right gives its child almost the full screen
/// height; a default Center expands to that height and can cover the app with
/// a giant invisible/grey overlay around the small audio controls.
class AudioDockPositioner extends StatelessWidget {
  const AudioDockPositioner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.paddingOf(context).bottom +
        (MediaQuery.sizeOf(context).width < 700 ? 78.0 : 12.0);
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
    return AudioDockPositioner(
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: SukunColors.deepTide.withValues(alpha: 0.18),
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
                    color: SukunColors.deepTide,
                    backgroundColor: SukunColors.softBlue,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          color: SukunColors.deepTide,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.currentTitle ?? 'অডিও',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
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
                        IconButton(
                          tooltip: playing ? 'বিরতি' : 'চালু করুন',
                          onPressed: playing
                              ? () => unawaited(controller.pause())
                              : controller.resumeCurrent,
                          icon: Icon(
                            playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                          ),
                          color: SukunColors.deepTide,
                          iconSize: 34,
                        ),
                        IconButton(
                          tooltip: _expanded ? 'কন্ট্রোল বন্ধ' : 'আরও কন্ট্রোল',
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          icon: Icon(
                            _expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'অডিও বন্ধ করুন',
                          icon: const Icon(Icons.close_rounded, size: 19),
                          onPressed: () => unawaited(controller.stopAndClear()),
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
                        final max = duration.inMilliseconds.toDouble();
                        final value = position.inMilliseconds
                            .clamp(0, duration.inMilliseconds)
                            .toDouble();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Slider(
                                value: max <= 0 ? 0 : value,
                                max: max <= 0 ? 1 : max,
                                onChanged: max <= 0
                                    ? null
                                    : (v) => unawaited(
                                        controller.seek(
                                          Duration(milliseconds: v.round()),
                                        ),
                                      ),
                              ),
                              Row(
                                children: [
                                  Text(_format(position)),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: isSequence
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
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => unawaited(
                                      controller.setSpeed(
                                        nextAudioPlaybackSpeed(player.speed),
                                      ),
                                    ),
                                    child: Text('${player.speed}×'),
                                  ),
                                  IconButton(
                                    tooltip: isSequence
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
                                    icon: const Icon(Icons.skip_next_rounded),
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
