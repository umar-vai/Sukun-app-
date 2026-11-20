import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_glass.dart';

const sukunPagePadding = EdgeInsets.symmetric(horizontal: 20);

Future<bool> showSukunDecisionDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool showCancel = true,
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SukunIconBadge(icon: icon, size: 56),
              const SizedBox(height: 17),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: SukunColors.muted),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (showCancel) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

enum SukunSurfaceTone { white, soft, blue, navy, warning, success }

class SukunSurface extends StatelessWidget {
  const SukunSurface({
    super.key,
    required this.child,
    this.tone = SukunSurfaceTone.white,
    this.padding = const EdgeInsets.all(20),
    this.radius = SukunRadius.card,
    this.onTap,
    this.showBorder = true,
  });

  final Widget child;
  final SukunSurfaceTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final color = switch (tone) {
      SukunSurfaceTone.white =>
        night ? theme.colorScheme.surface : Colors.white,
      SukunSurfaceTone.soft => theme.colorScheme.primaryContainer,
      SukunSurfaceTone.blue => theme.colorScheme.primary,
      SukunSurfaceTone.navy => SukunColors.nightNavy,
      SukunSurfaceTone.warning =>
        night ? theme.colorScheme.surfaceContainerLow : SukunColors.warningSoft,
      SukunSurfaceTone.success =>
        night ? theme.colorScheme.surfaceContainerLow : SukunColors.successSoft,
    };
    final dark = tone == SukunSurfaceTone.blue || tone == SukunSurfaceTone.navy;
    // Dark surfaces re-theme their text and icons: Material resets the
    // default text style, and theme text styles carry explicit Night Navy,
    // so a plain DefaultTextStyle alone would leave text invisible on navy.
    final themedChild = dark
        ? Theme(
            data: theme.copyWith(
              textTheme: theme.textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
              iconTheme: theme.iconTheme.copyWith(color: Colors.white),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: child,
              ),
            ),
          )
        : child;
    final paddedContent = Padding(padding: padding, child: themedChild);
    final content = onTap == null
        ? Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: paddedContent,
          )
        : _SurfaceInk(onTap: onTap!, radius: radius, child: paddedContent);
    if (!dark) {
      // Light panels are frosted glass in both Light and Dark mode.
      final glassTone = tone == SukunSurfaceTone.white
          ? SukunGlassTone.surface
          : SukunGlassTone.accent;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: night
              ? null
              : [
                  BoxShadow(
                    color: SukunColors.deepTide.withValues(alpha: 0.06),
                    blurRadius: 26,
                    spreadRadius: -8,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: SukunGlass(
          borderRadius: BorderRadius.circular(radius),
          tone: glassTone,
          tint: tone == SukunSurfaceTone.white ? null : color,
          showBorder: showBorder || tone == SukunSurfaceTone.white,
          child: content,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder && !dark && !night && tone != SukunSurfaceTone.white
            ? Border.all(color: Colors.white.withValues(alpha: 0.7))
            : null,
        boxShadow: !night && tone == SukunSurfaceTone.white
            ? [
                BoxShadow(
                  color: SukunColors.deepTide.withValues(alpha: 0.07),
                  blurRadius: 28,
                  spreadRadius: -4,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: SukunColors.nightNavy.withValues(alpha: 0.035),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : dark && !night
            ? [
                BoxShadow(
                  color: SukunColors.nightNavy.withValues(alpha: 0.22),
                  blurRadius: 26,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: content,
    );
  }
}

class _SurfaceInk extends StatelessWidget {
  const _SurfaceInk({
    required this.onTap,
    required this.radius,
    required this.child,
  });

  final VoidCallback onTap;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: child),
  );
}

/// Signature page header: a calm Mist panel with soft light shapes.
/// Used at the top of most screens so every page opens the same way.
class SukunPageIntro extends StatelessWidget {
  const SukunPageIntro({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.note,
    this.trailing,
  });

  final String title;
  final String? eyebrow;

  /// Explanatory copy under a title. Kept for API compatibility but not
  /// shown: the owner asked for clean, title-only headings (2026-11-12).
  final String? subtitle;

  /// Live information that must stay visible (a status, an instruction the
  /// user acts on now). Shown under the title.
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final panel = night
        ? theme.colorScheme.surfaceContainerLow
        : SukunColors.mist;
    final shape = night
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.6);
    final titleColor = night ? Colors.white : SukunColors.nightNavy;
    return SizedBox(
      width: double.infinity,
      child: SukunGlass(
        borderRadius: BorderRadius.circular(28),
        tone: SukunGlassTone.accent,
        tint: panel,
        child: Stack(
          children: [
            Positioned(
              right: -46,
              top: -58,
              child: _Blob(size: 170, color: shape),
            ),
            Positioned(
              right: 64,
              bottom: -70,
              child: _Blob(size: 120, color: shape),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: SukunColors.saffron,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  eyebrow!.toUpperCase(),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: night
                                        ? theme.colorScheme.secondary
                                        : SukunColors.deepTide,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        if (note != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            note!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: night ? Colors.white70 : SukunColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 14),
                    IconTheme.merge(
                      data: IconThemeData(color: SukunColors.deepTide),
                      child: trailing!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class SukunSectionHeader extends StatelessWidget {
  const SukunSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.note,
    this.action,
  });

  final String title;

  /// Explanatory copy. Kept for API compatibility but not shown: headings
  /// are title-only (owner request 2026-11-12).
  final String? subtitle;

  /// Live information that must stay visible (counts, status).
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
            ),
            if (note != null) ...[
              const SizedBox(height: 3),
              Text(
                note!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: SukunColors.muted),
              ),
            ],
          ],
        ),
      ),
      ?action,
    ],
  );
}

class SukunIconBadge extends StatelessWidget {
  const SukunIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.size = 48,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(size * 0.34),
    ),
    alignment: Alignment.center,
    child: Icon(
      icon,
      color: color ?? Theme.of(context).colorScheme.onPrimaryContainer,
      size: size * 0.48,
    ),
  );
}

class SukunStatusPill extends StatelessWidget {
  const SukunStatusPill({
    super.key,
    required this.label,
    this.tone = SukunStatusTone.neutral,
    this.icon,
  });

  final String label;
  final SukunStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      SukunStatusTone.brand => (
        Theme.of(context).colorScheme.primaryContainer,
        Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      SukunStatusTone.success => (SukunColors.successSoft, SukunColors.success),
      SukunStatusTone.warning => (
        SukunColors.warningSoft,
        const Color(0xFF7A5A10),
      ),
      SukunStatusTone.danger => (SukunColors.errorSoft, SukunColors.error),
      SukunStatusTone.neutral => (const Color(0xFFF0F4F6), SukunColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

enum SukunStatusTone { brand, success, warning, danger, neutral }

class SukunFilterPill extends StatelessWidget {
  const SukunFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final selectedFill = night
        ? theme.colorScheme.primary
        : SukunColors.nightNavy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? selectedFill
              : (night ? theme.colorScheme.surface : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? selectedFill
                : (night ? theme.colorScheme.outline : SukunColors.border),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? (night ? theme.colorScheme.onPrimary : Colors.white)
                : (night ? theme.colorScheme.onSurface : SukunColors.muted),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class SukunSearchField extends StatelessWidget {
  const SukunSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? scheme.surfaceContainerLow : Colors.white;
    final contentColor = scheme.onSurface;
    final subtleColor = scheme.onSurface.withValues(
      alpha: isDark ? 0.74 : 0.64,
    );

    return Container(
      key: const Key('sukun-search-surface'),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? scheme.outline.withValues(alpha: 0.62)
              : SukunColors.border,
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: SukunColors.nightNavy.withValues(alpha: 0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(color: contentColor),
        cursorColor: scheme.primary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(color: subtleColor),
          prefixIcon: Icon(Icons.search_rounded, color: subtleColor),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: subtleColor),
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class SukunChoiceOption<T> {
  const SukunChoiceOption({
    required this.value,
    required this.title,
    this.description,
    this.icon,
  });

  final T value;
  final String title;
  final String? description;
  final IconData? icon;
}

class SukunChoiceField<T> extends StatelessWidget {
  const SukunChoiceField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.options,
    required this.onChanged,
    this.value,
    this.helperText,
    this.sheetTitle,
    this.enabled = true,
  });

  final String label;
  final String placeholder;
  final List<SukunChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final T? value;
  final String? helperText;
  final String? sheetTitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    SukunChoiceOption<T>? selected;
    for (final option in options) {
      if (option.value == value) selected = option;
    }
    return Semantics(
      button: true,
      label: '$label, ${selected?.title ?? placeholder}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: !enabled
            ? null
            : () async {
                final result = await showModalBottomSheet<T>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (context) => _SukunChoiceSheet<T>(
                    title: sheetTitle ?? label,
                    options: options,
                    value: value,
                  ),
                );
                if (result != null) onChanged(result);
              },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.55,
          child: Ink(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SukunColors.border),
            ),
            child: Row(
              children: [
                if (selected?.icon != null) ...[
                  SukunIconBadge(icon: selected!.icon!, size: 42),
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: SukunColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected?.title ?? placeholder,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: selected == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if ((selected?.description ?? helperText)
                          case final text?) ...[
                        const SizedBox(height: 4),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: SukunColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: SukunColors.deepTide,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SukunChoiceSheet<T> extends StatelessWidget {
  const _SukunChoiceSheet({
    required this.title,
    required this.options,
    required this.value,
  });

  final String title;
  final List<SukunChoiceOption<T>> options;
  final T? value;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: options.length > 5 ? 0.78 : null,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: options.length > 5 ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SukunPageIntro(
            eyebrow: 'Choose one',
            title: title,
            subtitle: 'Review the description before applying this setting.',
          ),
          const SizedBox(height: 20),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = option.value == value;
                return SukunSurface(
                  tone: selected
                      ? SukunSurfaceTone.soft
                      : SukunSurfaceTone.white,
                  radius: 18,
                  padding: const EdgeInsets.all(16),
                  onTap: () => Navigator.pop(context, option.value),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (option.icon != null) ...[
                        SukunIconBadge(icon: option.icon!, size: 42),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (option.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                option.description!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: SukunColors.muted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selected
                              ? SukunColors.sukunBlue
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? SukunColors.sukunBlue
                                : SukunColors.border,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class SukunNavDestination {
  const SukunNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Unread count shown on the icon; hidden at zero.
  final int badgeCount;
}

class SukunBottomNavigation extends StatelessWidget {
  const SukunBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    this.leadingAction,
    this.navyEmphasis = false,
  });

  /// The bar is 70 high plus 8/10 safe-area margins. A floating player also
  /// needs a small gap to avoid obscuring navigation across desktop and mobile.
  static const double audioDockClearance = 98;

  final int selectedIndex;
  final List<SukunNavDestination> destinations;
  final ValueChanged<int> onSelected;
  final Widget? leadingAction;

  /// Admin mode marks the active tab with a solid palette-strong pill so
  /// staff always know they are in the management area.
  final bool navyEmphasis;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    // A floating iOS style glass bar: page content scrolls behind it and is
    // seen blurred through the frost.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: (night ? Colors.black : SukunColors.deepTide).withValues(
                alpha: night ? 0.30 : 0.12,
              ),
              blurRadius: 30,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SukunGlass(
          borderRadius: BorderRadius.circular(26),
          blur: 26,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                if (leadingAction != null) ...[
                  SizedBox(width: 46, child: leadingAction),
                  const SizedBox(width: 3),
                ],
                for (var index = 0; index < destinations.length; index++)
                  Expanded(
                    child: _SukunNavItem(
                      destination: destinations[index],
                      selected: index == selectedIndex,
                      navyEmphasis: navyEmphasis && !night,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SukunNavItem extends StatelessWidget {
  const _SukunNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.navyEmphasis = false,
  });

  final SukunNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool navyEmphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Admin mode marks the active tab in the palette's strong tone, so the
    // management area still follows the chosen colour theme.
    final activeBackground = navyEmphasis
        ? SukunColors.deepTide
        : scheme.primaryContainer;
    final activeIcon = navyEmphasis ? Colors.white : scheme.onPrimaryContainer;
    final activeLabel = navyEmphasis
        ? SukunColors.deepTide
        : scheme.onPrimaryContainer;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.badgeCount > 0
          ? '${destination.label}, ${destination.badgeCount}টি নতুন'
          : destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 54 : 40,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? activeBackground : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Badge(
                  isLabelVisible: destination.badgeCount > 0,
                  backgroundColor: SukunColors.error,
                  textColor: Colors.white,
                  label: Text(
                    destination.badgeCount > 9
                        ? '9+'
                        : '${destination.badgeCount}',
                  ),
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 22,
                    color: selected ? activeIcon : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? activeLabel : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three steps of turning a prescription into an approved plan.
const sukunPlanFlowSteps = ['লিখুন', 'যাচাই', 'অনুমোদন'];

/// Calm horizontal progress for multi-step admin flows. [current] is
/// zero-based; earlier steps read as done, later ones as upcoming.
class SukunStepper extends StatelessWidget {
  const SukunStepper({
    super.key,
    required this.current,
    this.steps = sukunPlanFlowSteps,
  });

  final int current;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'ধাপ ${current + 1} / ${steps.length}: ${steps[current]}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  key: Key('sukun-step-$i'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= current
                            ? SukunColors.sukunBlue
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(SukunRadius.chip),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${i + 1}. ${steps[i]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        color: i == current
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontWeight: i == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A bottom bar that keeps the screen's main actions in reach while the
/// content scrolls, instead of buttons buried at the end of a long page.
class SukunBottomActionBar extends StatelessWidget {
  const SukunBottomActionBar({super.key, required this.children, this.hint});

  final List<Widget> children;
  final Widget? hint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      boxShadow: [
        BoxShadow(
          color: SukunColors.nightNavy.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        SukunSpace.page,
        SukunSpace.md,
        SukunSpace.page,
        SukunSpace.md,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hint != null) ...[hint!, const SizedBox(height: 8)],
              Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Signature Deep Tide hero for primary dashboards. An optional [overlap]
/// card floats half over the hero's lower edge.
class SukunHeroHeader extends StatelessWidget {
  const SukunHeroHeader({super.key, required this.greeting, this.overlap});

  final Widget greeting;
  final Widget? overlap;

  @override
  Widget build(BuildContext context) {
    final hero = SukunColors.deepTide;
    final card = overlap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: hero,
            borderRadius: card == null
                ? const BorderRadius.vertical(bottom: Radius.circular(32))
                : null,
          ),
          child: Stack(
            children: [
              const Positioned(
                right: -60,
                top: -110,
                child: _HeroCircle(size: 190),
              ),
              const Positioned(
                left: -70,
                top: -40,
                child: _HeroCircle(size: 120),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, card == null ? 26 : 20),
                child: greeting,
              ),
            ],
          ),
        ),
        if (card != null)
          Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 64,
                child: Container(
                  decoration: BoxDecoration(
                    color: hero,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: card,
              ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.07),
    ),
  );
}
