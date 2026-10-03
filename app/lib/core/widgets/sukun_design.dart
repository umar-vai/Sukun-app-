import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

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
    this.radius = 24,
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
    final color = switch (tone) {
      SukunSurfaceTone.white => Colors.white,
      SukunSurfaceTone.soft => SukunColors.paleBlue,
      SukunSurfaceTone.blue => SukunColors.sukunBlue,
      SukunSurfaceTone.navy => SukunColors.nightNavy,
      SukunSurfaceTone.warning => SukunColors.warningSoft,
      SukunSurfaceTone.success => SukunColors.successSoft,
    };
    final dark = tone == SukunSurfaceTone.blue || tone == SukunSurfaceTone.navy;
    final paddedContent = Padding(padding: padding, child: child);
    final content = onTap == null
        ? Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: paddedContent,
          )
        : _SurfaceInk(onTap: onTap!, radius: radius, child: paddedContent);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder && !dark
            ? Border.all(color: SukunColors.border.withValues(alpha: 0.78))
            : null,
        boxShadow: tone == SukunSurfaceTone.white
            ? [
                BoxShadow(
                  color: SukunColors.nightNavy.withValues(alpha: 0.065),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ]
            : null,
      ),
      child: dark
          ? DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: content,
              ),
            )
          : content,
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

class SukunPageIntro extends StatelessWidget {
  const SukunPageIntro({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: SukunColors.deepTide,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.15,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: SukunColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 14), trailing!],
      ],
    );
  }
}

class SukunSectionHeader extends StatelessWidget {
  const SukunSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
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
    this.color = SukunColors.deepTide,
    this.backgroundColor = SukunColors.softBlue,
    this.size = 48,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(size * 0.34),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: size * 0.48),
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
      SukunStatusTone.brand => (SukunColors.softBlue, SukunColors.deepTide),
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? SukunColors.nightNavy : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? SukunColors.nightNavy : SukunColors.border,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? Colors.white : SukunColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SukunColors.border),
      boxShadow: [
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
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    ),
  );
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
                              ? SukunColors.muted
                              : SukunColors.nightNavy,
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
                const Icon(
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
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class SukunBottomNavigation extends StatelessWidget {
  const SukunBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<SukunNavDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SukunColors.canvas,
      boxShadow: [
        BoxShadow(
          color: SukunColors.nightNavy.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SukunColors.border.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _SukunNavItem(
                  destination: destinations[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SukunNavItem extends StatelessWidget {
  const _SukunNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final SukunNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: destination.label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? SukunColors.softBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 22,
              color: selected ? SukunColors.deepTide : SukunColors.muted,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                destination.label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? SukunColors.deepTide : SukunColors.muted,
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
