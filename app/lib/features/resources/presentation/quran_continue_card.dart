import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/resources/data/quran_last_read_store.dart';

/// "Continue reading" card. Shows nothing until a place has been saved on
/// this device, so first-time readers never see an empty card.
class QuranContinueCard extends StatefulWidget {
  const QuranContinueCard({super.key, this.onOpen});

  /// Defaults to pushing the saved reader route.
  final ValueChanged<QuranLastRead>? onOpen;

  @override
  State<QuranContinueCard> createState() => _QuranContinueCardState();
}

class _QuranContinueCardState extends State<QuranContinueCard> {
  @override
  void initState() {
    super.initState();
    QuranLastReadStore.load();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<QuranLastRead?>(
    valueListenable: QuranLastReadStore.current,
    builder: (context, lastRead, _) {
      if (lastRead == null) return const SizedBox.shrink();
      final textTheme = Theme.of(context).textTheme;
      return SukunSurface(
        key: const Key('quran-continue-reading'),
        padding: const EdgeInsets.all(14),
        onTap: () => widget.onOpen != null
            ? widget.onOpen!(lastRead)
            : context.push(lastRead.route),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: SukunColors.deepTide,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue Reading',
                    style: textTheme.labelMedium?.copyWith(
                      color: SukunColors.deepTide,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastRead.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'আয়াত ${lastRead.ayah} থেকে',
                    style: textTheme.bodySmall?.copyWith(
                      color: SukunColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8AA3B5)),
          ],
        ),
      );
    },
  );
}
