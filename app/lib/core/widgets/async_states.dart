import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/core/errors/friendly_failures.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.label = 'তথ্য আনা হচ্ছে…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    // Callers may still supply internal English progress labels; do not
    // surface technical loading details to patients or administrators.
    final displayLabel = RegExp(r'[\u0980-\u09FF]').hasMatch(label)
        ? label
        : (copy?.loading ?? 'তথ্য আনা হচ্ছে…');
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 180;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 24),
            child: Semantics(
              liveRegion: true,
              label: displayLabel,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: SukunSurface(
                  tone: SukunSurfaceTone.soft,
                  showBorder: false,
                  padding: EdgeInsets.all(compact ? 12 : 20),
                  child: compact
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _SukunLoadingMark(size: 28),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                displayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _SukunLoadingMark(),
                            const SizedBox(height: 16),
                            Text(
                              displayLabel,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SukunLoadingMark extends StatefulWidget {
  const _SukunLoadingMark({this.size = 42});

  final double size;

  @override
  State<_SukunLoadingMark> createState() => _SukunLoadingMarkState();
}

class _SukunLoadingMarkState extends State<_SukunLoadingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: SukunColors.softBlue,
          width: widget.size < 36 ? 4 : 5,
        ),
      ),
      child: const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 8,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SukunColors.sukunBlue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SukunSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SukunIconBadge(
                  icon: Icons.cloud_off_rounded,
                  color: SukunColors.error,
                  backgroundColor: SukunColors.errorSoft,
                  size: 58,
                ),
                const SizedBox(height: 16),
                Text(
                  Localizations.of<AppLocalizations>(context, AppLocalizations)
                          ?.attentionRequired ??
                      'এই মুহূর্তে কাজটি করা যাচ্ছে না',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 7),
                Text(
                  FriendlyFailures.generic(context),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: SukunColors.muted),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      Localizations.of<AppLocalizations>(context, AppLocalizations)
                              ?.tryAgain ??
                          'আবার চেষ্টা করুন',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SukunSurface(
            tone: SukunSurfaceTone.soft,
            showBorder: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SukunIconBadge(icon: icon, size: 58),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: SukunColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
