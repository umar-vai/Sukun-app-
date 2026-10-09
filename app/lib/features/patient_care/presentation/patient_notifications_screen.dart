import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/notifications/notification_inbox_providers.dart';
import 'package:sukun_life/core/notifications/notification_inbox_repository.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// Server-sent notices only. Scheduled local alarms are not claimed as history.
class PatientNotificationsScreen extends ConsumerStatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  ConsumerState<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends ConsumerState<PatientNotificationsScreen> {
  late Future<List<PatientInboxMessage>> _messages;
  final Set<String> _acknowledgedOpenedIds = {};
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _messages = _load();
  }

  Future<List<PatientInboxMessage>> _load() async {
    final messages = await ref
        .read(notificationInboxRepositoryProvider)
        .getRecentMessages();
    // A server read acknowledgment may be eventually consistent. Keep the
    // current session's confirmed read state during a pull-to-refresh.
    return [
      for (final message in messages)
        _acknowledgedOpenedIds.contains(message.id)
            ? message.asOpened()
            : message,
    ];
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _messages = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder renders an actionable error.
    }
  }

  Future<void> _open(PatientInboxMessage message) async {
    if (_openingId != null) return;
    setState(() => _openingId = message.id);
    try {
      if (!message.opened) {
        await ref
            .read(notificationInboxRepositoryProvider)
            .markOpened(message.id);
        _acknowledgedOpenedIds.add(message.id);
      }
      if (!mounted) return;
      final current = await _messages;
      if (!mounted) return;
      setState(() {
        _messages = Future.value([
          for (final item in current)
            item.id == message.id ? item.asOpened() : item,
        ]);
      });
      context.push(message.safeTargetRoute);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('বার্তাটি খোলা যাচ্ছে না। আবার চেষ্টা করুন।'),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আমার বার্তা')),
      body: FutureBuilder<List<PatientInboxMessage>>(
        future: _messages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'বার্তাগুলো আনা হচ্ছে…');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'বার্তাগুলো এখন আনা যাচ্ছে না।',
              onRetry: () => _refresh(),
            );
          }
          final messages = snapshot.data ?? const <PatientInboxMessage>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const SukunPageIntro(
                  eyebrow: 'আপনার অ্যাকাউন্ট',
                  title: 'সাম্প্রতিক বার্তা',
                  subtitle: 'পাঠানো বার্তাগুলো এখানে পাবেন। ফোনের সাধারণ অ্যালার্ম এখানে থাকে না।',
                ),
                const SizedBox(height: 18),
                if (messages.isEmpty)
                  const SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'এখনো কোনো বার্তা আসেনি। নতুন বার্তা এলে এখানে দেখতে পাবেন।',
                      ),
                    ),
                  )
                else ...[
                  Text(
                    '${messages.where((message) => !message.opened).length}টি নতুন বার্তা',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final message in messages) ...[
                    SukunSurface(
                      tone: message.opened
                          ? SukunSurfaceTone.white
                          : SukunSurfaceTone.soft,
                      onTap: _openingId == null ? () => _open(message) : null,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            message.opened
                                ? Icons.mark_email_read_outlined
                                : Icons.mark_email_unread_outlined,
                            color: SukunColors.deepTide,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.titleBn,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(message.descriptionBn),
                                const SizedBox(height: 6),
                                Text(
                                  _messageTime(context, message.scheduledAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (_openingId == message.id)
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (!message.opened)
                            const Text('নতুন'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _messageTime(BuildContext context, DateTime time) {
  final local = time.toLocal();
  return '${local.day}/${local.month}/${local.year} · '
      '${TimeOfDay.fromDateTime(local).format(context)}';
}
