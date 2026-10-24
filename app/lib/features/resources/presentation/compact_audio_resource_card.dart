import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/media_library/presentation/audio_library_actions.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Shared compact card for published audio in search and Ruqyah lists.
/// The library actions keep the existing resource-ID and rights checks.
class CompactAudioResourceCard extends StatelessWidget {
  const CompactAudioResourceCard({
    required this.resource,
    required this.onTap,
    super.key,
  });

  final ContentResource resource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = resource.titleBn?.trim().isNotEmpty == true
        ? resource.titleBn!
        : resource.title;
    final scheme = Theme.of(context).colorScheme;
    return SukunSurface(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A single menu avoids crushing long Bangla titles on narrow phones.
          final narrow = constraints.maxWidth < 280;
          return Row(
            children: [
              SukunIconBadge(icon: Icons.headphones_rounded, size: 40),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SukunTypography.banglaBody(
                        textStyle: Theme.of(context).textTheme.titleSmall,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'অডিও',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              AudioLibraryActions(
                resource: resource.linkedResource,
                compact: true,
                overflow: narrow,
              ),
              if (!narrow)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          );
        },
      ),
    );
  }
}
