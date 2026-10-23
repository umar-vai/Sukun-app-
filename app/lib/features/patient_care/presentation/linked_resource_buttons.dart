import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/audio_library_actions.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// Keeps the approved resource order and each practitioner's usage note visible.
class LinkedResourceButtons extends StatelessWidget {
  const LinkedResourceButtons({
    super.key,
    required this.resources,
    required this.onOpenResource,
  });

  final List<LinkedResource> resources;
  final void Function(LinkedResource)? onOpenResource;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final resource in resources)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: OutlinedButton.icon(
                        onPressed: onOpenResource == null
                            ? null
                            : () => onOpenResource!(resource),
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(
                          resource.titleBn ?? resource.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (resource.type == 'audio')
                      AudioLibraryActions(
                        resourceId: resource.id,
                        compact: true,
                      ),
                  ],
                ),
                if (resource.usageNote?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      resource.usageNote!.trim(),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: SukunColors.muted),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
