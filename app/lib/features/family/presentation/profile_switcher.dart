import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/features/family/domain/family_profile.dart';

const profileSwitchLabelBn = 'প্রোফাইল পরিবর্তন';
const familyProfilesTitleBn = 'ফ্যামিলি প্রোফাইল';
const familyDisclosureBn =
    'একই ফ্যামিলির সংযুক্ত প্রোফাইলগুলোর রোগীকে দেখানো তথ্য এই লগইনে একসাথে দেখা যায়।';

/// Top-right control for the authenticated app bar.
///
/// Renders nothing unless the login has more than one profile, so single
/// patient accounts look exactly as they did before family accounts.
class ProfileSwitcherButton extends ConsumerWidget {
  const ProfileSwitcherButton({super.key, this.onDarkBar = false});

  /// True on the Deep Tide home app bar, where the avatar needs a light ring.
  final bool onDarkBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeProfileProvider).value;
    if (state == null || !state.hasMultipleProfiles) {
      return const SizedBox.shrink();
    }
    final active = state.active;
    return Tooltip(
      message: profileSwitchLabelBn,
      child: Semantics(
        button: true,
        label: '$profileSwitchLabelBn, ${active.fullName}',
        excludeSemantics: true,
        child: InkResponse(
          key: const Key('profile-switcher'),
          onTap: () => showProfileSwitcherSheet(context),
          radius: 26,
          child: SizedBox(
            // 48 px keeps a comfortable tap target around a 36 px avatar.
            width: 48,
            height: 48,
            child: Center(
              child: ProfileAvatar(
                profile: active,
                size: 36,
                ring: onDarkBar ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.size = 44,
    this.ring,
  });

  final FamilyProfile profile;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SukunColors.brandMist,
        border: ring == null ? null : Border.all(color: ring!, width: 2),
      ),
      child: ExcludeSemantics(
        child: Text(
          profile.initials,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: SukunColors.deepTide,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

Future<void> showProfileSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeProfileProvider).value;
    final theme = Theme.of(context);
    if (state == null) return const SizedBox.shrink();
    // One scrolling column (header, rows, disclosure) so nothing can
    // overflow on a compact phone or with large text; five or more profiles
    // simply scroll.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text(familyProfilesTitleBn, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            profileSwitchLabelBn,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SukunColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          for (final profile in state.profiles) ...[
            _ProfileRow(
              profile: profile,
              selected: profile.patientId == state.active.patientId,
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(activeProfileProvider.notifier)
                    .select(profile.patientId);
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: SukunColors.mist,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: SukunColors.deepTide,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      familyDisclosureBn,
                      key: const Key('family-disclosure'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SukunColors.nightNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final FamilyProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: SukunSurface(
        key: Key('profile-row-${profile.patientId}'),
        tone: selected ? SukunSurfaceTone.soft : SukunSurfaceTone.white,
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            ProfileAvatar(profile: profile),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Long Bangla names wrap to two lines instead of clipping.
                  Text(
                    profile.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (profile.relationshipLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.relationshipLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SukunColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (selected)
              Container(
                key: const Key('profile-selected-check'),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: SukunColors.sukunBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              )
            else
              const SizedBox(width: 24, height: 24),
          ],
        ),
      ),
    );
  }
}
