import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_seen_store.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_announcements_screen.dart';

/// The single app-wide overlay is shared by Flutter Web/Android/iOS. It uses
/// the public published feed only and never queries patient care records.
class UniversalNoticeAutoPopup extends ConsumerStatefulWidget {
  const UniversalNoticeAutoPopup({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UniversalNoticeAutoPopup> createState() =>
      _UniversalNoticeAutoPopupState();
}

class _UniversalNoticeAutoPopupState
    extends ConsumerState<UniversalNoticeAutoPopup>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _checking = false;
  UniversalAnnouncement? _active;
  String? _activeOwner;
  int _checkGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_check()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_check());
    }
  }

  String? _owner() => ref.read(appSessionProvider).value?.userId;

  bool _eligibleRoute() {
    final route = ref
        .read(appRouterProvider)
        .routeInformationProvider
        .value
        .uri
        .path;
    // Never interrupt login, patient credential updates or the admin editor.
    if (route.startsWith('/announcements') ||
        route.startsWith('/admin/announcements') ||
        route.startsWith('/login') ||
        route.startsWith('/register') ||
        route.startsWith('/patient/change-password')) {
      return false;
    }
    return true;
  }

  Future<void> _check() async {
    if (_checking || _active != null) return;
    final auth = ref.read(appSessionProvider);
    if (!auth.hasValue || auth.value?.requiresCredentialChange == true) {
      return;
    }
    if (!_eligibleRoute()) return;

    final ownerId = _owner();
    final generation = ++_checkGeneration;
    _checking = true;
    try {
      final notices = await ref
          .read(announcementRepositoryProvider)
          .recentPublished();
      final seenStore = ref.read(universalNoticeSeenStoreProvider);
      final seen = await seenStore.read(ownerId);
      final fresh = nextUnseenUniversalNotice(notices, seen);
      if (fresh == null ||
          !mounted ||
          _owner() != ownerId ||
          generation != _checkGeneration ||
          !_eligibleRoute()) {
        return;
      }

      // Persist the exact publication before opening the panel so refreshes
      // and app restarts do not replay it. Cloud sync is owner-scoped by RLS.
      await seenStore.mark(fresh, ownerId);
      if (!mounted ||
          _owner() != ownerId ||
          generation != _checkGeneration ||
          !_eligibleRoute()) {
        return;
      }
      setState(() {
        _active = fresh;
        _activeOwner = ownerId;
      });
    } catch (_) {
      // Backend offline or unavailable: never block the actual app.
      // The next foreground/poll attempt will retry.
    } finally {
      _checking = false;
    }
  }

  void _close() {
    setState(() {
      _active = null;
      _activeOwner = null;
    });
    // Future polls can surface another newly published notice, but closing
    // one does not immediately flood the screen with older notices.
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSessionProvider, (previous, next) {
      final oldUser = previous?.value?.userId;
      final newUser = next.value?.userId;
      if (!next.hasValue ||
          (previous?.hasValue == true && oldUser == newUser)) {
        return;
      }
      _checkGeneration++;
      if (_active != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _close();
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_check());
      });
    });

    // A tapped notice detail route must take precedence over any automatic
    // publish-time overlay, even when the app resumes from Android background.
    return ListenableBuilder(
      listenable: ref.watch(appRouterProvider).routeInformationProvider,
      builder: (context, _) {
        final path = ref
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path;
        final onNoticeRoute = path.startsWith('/announcements');
        if (onNoticeRoute && _active != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_eligibleRoute()) _close();
          });
        }
        final notice = onNoticeRoute ? null : _active;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (notice != null && _activeOwner == _owner())
              Positioned.fill(
                // MaterialApp.router.builder sits ABOVE Navigator's Overlay.
                // The public notice popup is therefore given its own
                // bounded Overlay, preserving Tooltip and text-selection
                // behavior without rebuilding or replacing the route stack.
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (overlayContext) => Stack(
                        fit: StackFit.expand,
                        children: [
                          const ModalBarrier(
                            dismissible: false,
                            color: Color(0x990D2B45),
                          ),
                          SafeArea(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 510,
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height *
                                        0.84,
                                  ),
                                  child: Material(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                    elevation: 14,
                                    borderRadius: BorderRadius.circular(22),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          height: 5,
                                          color: const Color(0xFFE6B53D),
                                        ),
                                        Flexible(
                                          child: UniversalNoticePanel(
                                            notice: notice,
                                            image: notice.imagePath == null
                                                ? null
                                                : NetworkImage(
                                                    ref
                                                        .read(
                                                          announcementRepositoryProvider,
                                                        )
                                                        .imageUrl(
                                                          notice.imagePath!,
                                                        ),
                                                  ),
                                            onClose: _close,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
