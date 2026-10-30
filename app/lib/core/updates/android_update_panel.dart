import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/updates/android_release.dart';
import 'package:sukun_life/core/updates/android_update_service.dart';

/// Checked on initial Android launch and when returning from background.
/// A failed release feed never locks out a member or patient.
class AndroidUpdateAutoPopup extends StatefulWidget {
  const AndroidUpdateAutoPopup({required this.child, super.key});

  final Widget child;

  @override
  State<AndroidUpdateAutoPopup> createState() => _AndroidUpdateAutoPopupState();
}

class _AndroidUpdateAutoPopupState extends State<AndroidUpdateAutoPopup>
    with WidgetsBindingObserver {
  late final AndroidUpdateService _service = AndroidUpdateService();
  AndroidRelease? _available;
  DateTime? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_service.isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_check());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _service.isSupported) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_checking || _available != null || !_service.isSupported) return;
    final previous = _lastCheck;
    if (previous != null &&
        DateTime.now().difference(previous) < const Duration(hours: 6)) {
      return;
    }
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final release = await _service.check();
      if (release == null || !mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final dismissedCode = prefs.getInt('sukun_dismissed_apk_code');
      final dismissedAt = prefs.getInt('sukun_dismissed_apk_at') ?? 0;
      final recentlyDismissed =
          dismissedCode == release.versionCode &&
          DateTime.now().millisecondsSinceEpoch - dismissedAt <
              const Duration(hours: 24).inMilliseconds;
      if (mounted && !recentlyDismissed) {
        setState(() => _available = release);
      }
    } catch (_) {
      // No backend/auth interaction and no interruption if release CDN is down.
    } finally {
      _checking = false;
    }
  }

  Future<void> _dismiss() async {
    final release = _available;
    setState(() => _available = null);
    if (release == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sukun_dismissed_apk_code', release.versionCode);
    await prefs.setInt(
      'sukun_dismissed_apk_at',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = _available;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (release != null) ...[
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x990D2B45)),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                    ),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 12,
                      borderRadius: BorderRadius.circular(22),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: AndroidUpdatePanel(
                          release: release,
                          service: _service,
                          onLater: _dismiss,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Used by the account screen. Explicit checks bypass the 24-hour snooze.
Future<void> checkAndroidUpdateManually(BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final messenger = ScaffoldMessenger.of(context);
  final service = AndroidUpdateService();
  try {
    final release = await service.check();
    if (!context.mounted) return;
    if (release == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('আপনার অ্যাপের সর্বশেষ সংস্করণ রয়েছে।')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        content: SizedBox(
          width: 390,
          child: SingleChildScrollView(
            child: AndroidUpdatePanel(
              release: release,
              service: service,
              onLater: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('আপডেট যাচাই করা যাচ্ছে না। পরে চেষ্টা করুন।'),
        ),
      );
    }
  } finally {
    service.dispose();
  }
}

/// Only an approved APK download can reach the native Android installer.
class AndroidUpdatePanel extends StatefulWidget {
  const AndroidUpdatePanel({
    required this.release,
    required this.service,
    required this.onLater,
    super.key,
  });

  final AndroidRelease release;
  final AndroidUpdateService service;
  final VoidCallback onLater;

  @override
  State<AndroidUpdatePanel> createState() => _AndroidUpdatePanelState();
}

class _AndroidUpdatePanelState extends State<AndroidUpdatePanel> {
  Timer? _poll;
  int? _downloadId;
  bool _pollBusy = false;
  bool _openingInstaller = false;
  String _status = 'idle';
  String? _error;
  double? _progress;

  Future<void> _startDownload() async {
    if (_status != 'idle' && _status != 'failed') return;
    setState(() {
      _status = 'pending';
      _error = null;
      _progress = null;
    });
    try {
      final id = await widget.service.startDownload(widget.release);
      if (!mounted) return;
      setState(() => _downloadId = id);
      _poll?.cancel();
      _poll = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_readProgress()),
      );
      await _readProgress();
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'failed';
          _error = 'ডাউনলোড শুরু করা যায়নি। ইন্টারনেট সংযোগ পরীক্ষা করুন।';
        });
      }
    }
  }

  Future<void> _readProgress() async {
    final id = _downloadId;
    if (id == null || _pollBusy) return;
    _pollBusy = true;
    try {
      final state = await widget.service.status(id);
      if (!mounted) return;
      setState(() {
        _status = state.state;
        _progress = state.progress;
      });
      if (state.state == 'ready') {
        // The verified APK is ready. Let the user tap "ইনস্টল করুন" rather
        // than automatically opening Android's installer after download.
        _poll?.cancel();
      } else if (state.state == 'failed' || state.state == 'integrity_failed') {
        _poll?.cancel();
        setState(() {
          _error = state.state == 'integrity_failed'
              ? 'APK যাচাই ব্যর্থ হয়েছে। এই ফাইল ইনস্টল করা হবে না।'
              : 'ডাউনলোড ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
        });
      }
    } catch (_) {
      _poll?.cancel();
      if (mounted) {
        setState(() {
          _status = 'failed';
          _error = 'ডাউনলোডের অবস্থা জানা যাচ্ছে না।';
        });
      }
    } finally {
      _pollBusy = false;
    }
  }

  Future<void> _install() async {
    if (_openingInstaller || _downloadId == null) return;
    _openingInstaller = true;
    try {
      final result = await widget.service.requestInstallation(_downloadId!);
      if (!mounted) return;
      setState(() {
        _status = result == 'permission_required'
            ? 'permission_required'
            : 'installer_opened';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'ready';
          _error = 'Android Installer খোলা যায়নি। আবার চেষ্টা করুন।';
        });
      }
    } finally {
      _openingInstaller = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = (widget.release.sizeBytes / (1024 * 1024)).toStringAsFixed(
      1,
    );
    final busy =
        _status == 'pending' || _status == 'downloading' || _status == 'paused';
    final ready = _status == 'ready' || _status == 'permission_required';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.system_update_alt, size: 36, color: Color(0xFF0F9BD7)),
        const SizedBox(height: 12),
        Text(
          'Sukun Life আপডেট পাওয়া গেছে',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('নতুন সংস্করণ ${widget.release.versionName} · প্রায় $sizeMb MB'),
        if (widget.release.notesBn.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(widget.release.notesBn),
        ],
        if (busy) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 6),
          const Text('Android ডাউনলোড ম্যানেজারে ফাইল আসছে…'),
        ],
        if (_status == 'permission_required') ...[
          const SizedBox(height: 12),
          const Text(
            'Android Settings-এ এই অ্যাপ থেকে ইনস্টলের অনুমতি দিন, '
            'তারপর ফিরে এসে “ইনস্টল করুন” চাপুন।',
          ),
        ],
        if (_status == 'installer_opened') ...[
          const SizedBox(height: 10),
          const Text('Android-এর ইনস্টলেশন অনুমোদন সম্পন্ন করুন।'),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (_status == 'idle' || _status == 'failed')
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('ডাউনলোড করুন'),
              ),
            if (ready)
              FilledButton.icon(
                onPressed: _install,
                icon: const Icon(Icons.install_mobile),
                label: const Text('ইনস্টল করুন'),
              ),
            TextButton(onPressed: widget.onLater, child: const Text('পরে করব')),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'APK ডাউনলোড শুরু হবে। ইনস্টলের আগে Android আপনার অনুমতি চাইবে। '
          'শুধু অফিসিয়াল Sukun Life-এর যাচাইকৃত ফাইল ব্যবহার করুন।',
        ),
      ],
    );
  }
}
