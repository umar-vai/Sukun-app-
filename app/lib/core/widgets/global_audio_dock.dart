import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';

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
    final size = MediaQuery.sizeOf(context);
    final bottom =
        MediaQuery.paddingOf(context).bottom + (size.width < 700 ? 78.0 : 12.0);
    return Positioned(
      bottom: bottom,
      left: 12,
      right: 12,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
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
                              tooltip: _expanded
                                  ? 'কন্ট্রোল বন্ধ'
                                  : 'আরও কন্ট্রোল',
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
                                                      const Duration(
                                                        seconds: 10,
                                                      ),
                                                ),
                                        ),
                                        icon: const Icon(
                                          Icons.skip_previous_rounded,
                                        ),
                                      ),
                                      PopupMenuButton<double>(
                                        tooltip: 'প্লেব্যাক গতি',
                                        onSelected: (speed) => unawaited(
                                          controller.setSpeed(speed),
                                        ),
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 0.75,
                                            child: Text('0.75×'),
                                          ),
                                          PopupMenuItem(
                                            value: 1.0,
                                            child: Text('1×'),
                                          ),
                                          PopupMenuItem(
                                            value: 1.25,
                                            child: Text('1.25×'),
                                          ),
                                          PopupMenuItem(
                                            value: 1.5,
                                            child: Text('1.5×'),
                                          ),
                                          PopupMenuItem(
                                            value: 2.0,
                                            child: Text('2×'),
                                          ),
                                        ],
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text('${player.speed}×'),
                                        ),
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
                                                      const Duration(
                                                        seconds: 10,
                                                      ),
                                                ),
                                        ),
                                        icon: const Icon(
                                          Icons.skip_next_rounded,
                                        ),
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
      ),
    );
  }

  String _format(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}
