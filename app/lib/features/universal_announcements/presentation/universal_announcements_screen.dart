import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_glass.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_push.dart';
import 'package:sukun_life/core/notifications/public_notice_tap_qa_diagnostics.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_seen_store.dart';
import 'package:sukun_life/features/notice_center/data/notice_center_providers.dart';
import 'package:sukun_life/features/notice_center/presentation/amal_reminders_tab.dart';

/// One public notice is always addressed by stable UUID. The route is valid
/// on a cold start, while authorization comes solely from database RLS.
class UniversalNoticeDetailScreen extends ConsumerStatefulWidget {
  const UniversalNoticeDetailScreen({super.key, required this.announcementId});
  final String announcementId;

  @override
  ConsumerState<UniversalNoticeDetailScreen> createState() =>
      _UniversalNoticeDetailScreenState();
}

class _UniversalNoticeDetailScreenState
    extends ConsumerState<UniversalNoticeDetailScreen> {
  late Future<UniversalAnnouncement?> _notice;

  @override
  void initState() {
    super.initState();
    _notice = ref
        .read(announcementRepositoryProvider)
        .get(widget.announcementId);
    // Opening a notice manually counts as seeing that publication, too.
    // This prevents an unnecessary automatic popup on the next visit.
    final owner = ref.read(appSessionProvider);
    if (owner.hasValue) {
      final store = ref.read(universalNoticeSeenStoreProvider);
      unawaited(
        _notice
            .then((notice) async {
              if (notice != null) {
                await store.mark(notice, owner.value?.userId);
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black54,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 510),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SukunGlass(
              borderRadius: BorderRadius.circular(24),
              tone: SukunGlassTone.surface,
              child: Material(
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                type: MaterialType.transparency,
                elevation: 8,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.83,
                  ),
                  child: FutureBuilder<UniversalAnnouncement?>(
                    future: _notice,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, size: 40),
                              const SizedBox(height: 12),
                              const Text('নোটিশটি পাওয়া যায়নি অথবা মেয়াদ শেষ।'),
                              TextButton(
                                onPressed: _close,
                                child: const Text('বন্ধ করুন'),
                              ),
                            ],
                          ),
                        );
                      }
                      return UniversalNoticePanel(
                        notice: snapshot.data!,
                        image: snapshot.data!.imagePath == null
                            ? null
                            : NetworkImage(
                                ref
                                    .read(announcementRepositoryProvider)
                                    .imageUrl(snapshot.data!.imagePath!),
                              ),
                        onClose: _close,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class UniversalNoticePanel extends StatelessWidget {
  const UniversalNoticePanel({
    required this.notice,
    required this.image,
    required this.onClose,
    this.isPreview = false,
    super.key,
  });

  final UniversalAnnouncement notice;
  final ImageProvider? image;
  final VoidCallback onClose;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(notice.linkUrl ?? '');
    final safeLink =
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: SukunColors.mist,
          padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.campaign_outlined, color: SukunColors.deepTide),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPreview
                      ? 'প্রকাশের আগে নোটিশ দেখুন'
                      : 'সুকুন লাইফ • গুরুত্বপূর্ণ নোটিশ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: SukunColors.nightNavy,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'নোটিশ বন্ধ করুন',
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: SukunColors.deepTide),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notice.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image(
                      image: image!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Padding(
                            padding: EdgeInsets.all(14),
                            child: Text('ছবি লোড করা যায়নি।'),
                          ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (notice.countdownEndsAt != null) ...[
                  UniversalNoticeCountdown(endsAt: notice.countdownEndsAt!),
                  const SizedBox(height: 12),
                ],
                SelectableText(notice.body),
                if (safeLink) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('লিংক খুলুন'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class UniversalNoticeCountdown extends StatefulWidget {
  const UniversalNoticeCountdown({required this.endsAt, super.key});

  final DateTime endsAt;

  @override
  State<UniversalNoticeCountdown> createState() =>
      _UniversalNoticeCountdownState();
}

class _UniversalNoticeCountdownState extends State<UniversalNoticeCountdown> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (widget.endsAt.isAfter(_now)) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        if (!widget.endsAt.isAfter(_now)) {
          _timer?.cancel();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant UniversalNoticeCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt == widget.endsAt) return;
    _timer?.cancel();
    _now = DateTime.now();
    if (widget.endsAt.isAfter(_now)) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        if (!widget.endsAt.isAfter(_now)) _timer?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(_now);
    final seconds = remaining.inSeconds;
    final expired = seconds <= 0;
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final sec = seconds % 60;
    String pad(int n) => n.toString().padLeft(2, '0');
    final time = expired
        ? 'সময় শেষ'
        : days > 0
        ? '$days দিন ${pad(hours)}:${pad(minutes)}:${pad(sec)}'
        : '${pad(hours)}:${pad(minutes)}:${pad(sec)}';
    return Semantics(
      label: expired ? 'কাউন্টডাউন শেষ' : 'কাউন্টডাউন বাকি $time',
      child: Container(
        key: const Key('universal-notice-countdown'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SukunColors.mist,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: SukunColors.deepTide),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                time,
                key: const Key('universal-notice-countdown-time'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.bold,
                  color: SukunColors.nightNavy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The notice centre. Signed-in Members and Patients get two sections:
/// amal reminders and Sukun Life notices. Guests and staff see notices only.
class UniversalAnnouncementsScreen extends ConsumerWidget {
  const UniversalAnnouncementsScreen({super.key, this.initialSection});

  /// `notices` opens the Sukun Life notice section first; otherwise the amal
  /// section opens first.
  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider).value;
    final showsAmal =
        session != null && (session.isMember || session.isPatient);
    final summary = ref.watch(noticeCenterProvider).value;
    void refresh() {
      ref.invalidate(publishedAnnouncementsProvider);
      ref.invalidate(noticeCenterProvider);
    }

    final refreshAction = IconButton(
      tooltip: 'আবার দেখুন',
      onPressed: refresh,
      icon: const Icon(Icons.refresh_rounded),
    );
    if (!showsAmal) {
      return Scaffold(
        appBar: AppBar(title: const Text('সব নোটিশ'), actions: [refreshAction]),
        body: const _NoticeList(),
      );
    }
    return DefaultTabController(
      length: 2,
      initialIndex: initialSection == 'notices' ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('নোটিশ'),
          actions: [refreshAction],
          bottom: TabBar(
            tabs: [
              Tab(
                key: const Key('notice-tab-amal'),
                child: _SectionTabLabel(
                  label: 'আমল রিমাইন্ডার',
                  count: summary?.amalCount ?? 0,
                ),
              ),
              Tab(
                key: const Key('notice-tab-notices'),
                child: _SectionTabLabel(
                  label: 'সুকুন লাইফ নোটিশ',
                  count: summary?.unseenNoticeCount ?? 0,
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [AmalRemindersTab(), _NoticeList()]),
      ),
    );
  }
}

class _SectionTabLabel extends StatelessWidget {
  const _SectionTabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      if (count > 0) ...[
        const SizedBox(width: 6),
        NoticeCountBadge(count: count),
      ],
    ],
  );
}

/// The small count bubble used on the notice button and section tabs.
class NoticeCountBadge extends StatelessWidget {
  const NoticeCountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$countটি নতুন',
    excludeSemantics: true,
    child: Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SukunColors.error,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    ),
  );
}

class _NoticeList extends ConsumerWidget {
  const _NoticeList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(publishedAnnouncementsProvider);
    final summary = ref.watch(noticeCenterProvider).value;
    return Column(
      children: [
        if (UniversalNoticePush.supported) const _UniversalPushToggle(),
        Expanded(
          child: items.when(
            loading: () => const AppLoadingState(label: 'নোটিশ আনা হচ্ছে…'),
            error: (error, stack) => AppErrorState(
              message: 'নোটিশ লোড করা যায়নি।',
              onRetry: () => ref.invalidate(publishedAnnouncementsProvider),
            ),
            data: (list) => list.isEmpty
                ? const AppEmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'এখন কোনো প্রকাশিত নোটিশ নেই।',
                    message: 'নতুন নোটিশ এলে এখানে দেখা যাবে।',
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(publishedAnnouncementsProvider);
                      ref.invalidate(noticeCenterProvider);
                      await ref.read(publishedAnnouncementsProvider.future);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        SukunSpace.page,
                        SukunSpace.sm,
                        SukunSpace.page,
                        SukunSpace.section,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notice = list[index];
                        final unseen = summary?.isNoticeUnseen(notice) ?? false;
                        return SukunSurface(
                          key: Key('notice-item-${notice.id}'),
                          padding: const EdgeInsets.all(14),
                          radius: SukunRadius.tile + 2,
                          onTap: () async {
                            await context.push<void>(
                              '/announcements/${notice.id}',
                            );
                            // Opening a notice marks it seen.
                            ref.invalidate(noticeCenterProvider);
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SukunIconBadge(
                                icon: Icons.campaign_outlined,
                                size: 42,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notice.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: unseen
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      notice.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: SukunColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              if (unseen)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8, top: 2),
                                  child: SukunStatusPill(
                                    label: 'নতুন',
                                    tone: SukunStatusTone.brand,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF8AA3B5),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _UniversalPushToggle extends StatefulWidget {
  const _UniversalPushToggle();

  @override
  State<_UniversalPushToggle> createState() => _UniversalPushToggleState();
}

class _UniversalPushToggleState extends State<_UniversalPushToggle> {
  bool _busy = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    UniversalNoticePush.isEnabled().then((enabled) {
      if (mounted) setState(() => _enabled = enabled);
    });
  }

  Future<void> _change(bool nextValue) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final success = nextValue
          ? await UniversalNoticePush.enable()
          : await UniversalNoticePush.disable().then((_) => true);
      if (!mounted) return;
      setState(() => _enabled = nextValue && success);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ফোনের নোটিফিকেশন অনুমতি প্রয়োজন।')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('নোটিফিকেশন চালু করা যায়নি। পরে চেষ্টা করুন।'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyTestToken() async {
    if (_busy || !UniversalNoticePush.canCopyQaToken) return;
    setState(() => _busy = true);
    try {
      final current = await UniversalNoticePush.currentQaToken();
      if (current == null || current.isEmpty) {
        throw StateError('Token unavailable');
      }
      await Clipboard.setData(ClipboardData(text: current));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('টেস্ট টোকেন কপি হয়েছে।')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('টেস্ট টোকেন পাওয়া যায়নি।')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SwitchListTile(
        title: const Text('সবার গুরুত্বপূর্ণ নোটিশ ফোনে পেতে চাই'),
        secondary: const Icon(Icons.notifications_active_outlined),
        value: _enabled,
        onChanged: _busy ? null : _change,
      ),
      if (UniversalNoticePush.canCopyQaToken)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: const Text('টেস্ট টোকেন কপি'),
              onPressed: _busy ? null : _copyTestToken,
            ),
          ),
        ),
      if (PublicNoticeTapQaDiagnostics.enabled)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ValueListenableBuilder<String>(
            valueListenable: PublicNoticeTapQaDiagnostics.status,
            builder: (context, status, _) =>
                Text(status, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
    ],
  );
}
