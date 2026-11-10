import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/updates/android_release.dart';
import 'package:sukun_life/core/updates/android_update_service.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:url_launcher/url_launcher.dart';

/// Optional build-time override for the download button. Only an approved
/// release URL is used; anything else falls back to [publicAndroidApkLink].
const androidApkUrl = String.fromEnvironment('ANDROID_APK_URL');

/// Shows the version and size from the update feed when switched on at build
/// time. The download button works without it.
const publicApkDownloadEnabled = bool.fromEnvironment(
  'ENABLE_PUBLIC_APK_DOWNLOAD',
  defaultValue: false,
);

/// The link people share. GitHub always serves the newest published release
/// asset named SukunLife.apk here, so it never changes between versions and
/// downloads the .apk itself (no ZIP, no sign-in).
const publicAndroidApkLink =
    'https://github.com/umar-vai/Sukun-app-/releases/latest/download/SukunLife.apk';

Uri? approvedAndroidApkUri(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && isApprovedApkUri(uri) ? uri : null;
}

/// The download target: an approved build-time URL, else the stable link.
Uri publicAndroidDownloadUri([String override = androidApkUrl]) =>
    approvedAndroidApkUri(override) ?? Uri.parse(publicAndroidApkLink);

/// What a signed-out visitor sees on app.sukunlife.com.
class PublicWelcomeScreen extends StatefulWidget {
  const PublicWelcomeScreen({super.key});

  @override
  State<PublicWelcomeScreen> createState() => _PublicWelcomeScreenState();
}

class _PublicWelcomeScreenState extends State<PublicWelcomeScreen> {
  late final AndroidUpdateService _updateService = AndroidUpdateService();
  late final Future<AndroidRelease?> _publishedRelease;

  @override
  void initState() {
    super.initState();
    _publishedRelease = publicApkDownloadEnabled
        ? _updateService
              .check(installedVersionCodeOverride: 0)
              .catchError((Object _) => null)
        : Future<AndroidRelease?>.value(null);
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _download(BuildContext context) async {
    final opened = await launchUrl(
      publicAndroidDownloadUri(),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ডাউনলোড লিংক খোলা যাচ্ছে না।')),
      );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: publicAndroidApkLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ডাউনলোড লিংক কপি হয়েছে।')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AndroidRelease?>(
      future: _publishedRelease,
      builder: (context, snapshot) {
        final release = snapshot.data;
        final small = MediaQuery.sizeOf(context).width < 760;
        final textTheme = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: SukunColors.canvas,
          body: SafeArea(
            child: ListView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: small ? 16 : 32,
                        vertical: small ? 16 : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _WelcomeHeader(),
                          SizedBox(height: small ? 28 : 56),
                          _WelcomeHero(
                            small: small,
                            release: release,
                            onDownload: () => _download(context),
                            onCopyLink: () => _copyLink(context),
                          ),
                          SizedBox(height: small ? 40 : 64),
                          Text(
                            'সুকুন লাইফে যা পাবেন',
                            style: textTheme.headlineSmall?.copyWith(
                              color: SukunColors.nightNavy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'আপনার দৈনন্দিন চর্চা ও নির্ভরযোগ্য উপকরণ এক জায়গায়।',
                            style: textTheme.bodyMedium?.copyWith(
                              color: SukunColors.muted,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _BenefitGrid(),
                          SizedBox(height: small ? 36 : 56),
                          _DownloadBand(
                            onDownload: () => _download(context),
                            onCopyLink: () => _copyLink(context),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'সুকুন লাইফ · আপনার যত্নের পথে সহযাত্রী',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: SukunColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final links = Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.go('/resources'),
          child: const Text('পাঠ ও অডিও'),
        ),
        TextButton(
          onPressed: () => context.go('/announcements'),
          child: const Text('নোটিশ'),
        ),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: const Text('লগইন'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 640
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const SukunLifeLogo(height: 44), links],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SukunLifeLogo(height: 40),
                const SizedBox(height: 10),
                links,
              ],
            ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({
    required this.small,
    required this.release,
    required this.onDownload,
    required this.onCopyLink,
  });

  final bool small;
  final AndroidRelease? release;
  final VoidCallback onDownload;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = release == null
        ? 'বিনামূল্যে · সরাসরি APK ফাইল · নতুন আপডেট অ্যাপের ভেতরেই আসবে'
        : 'সংস্করণ ${release!.versionName} · প্রায় '
              '${(release!.sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB · '
              'নতুন আপডেট অ্যাপের ভেতরেই আসবে';
    final message = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: SukunColors.mist,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.android_rounded,
                size: 18,
                color: SukunColors.deepTide,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Android অ্যাপ এখন ডাউনলোড করা যাচ্ছে',
                  style: TextStyle(color: SukunColors.deepTide),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'যত্ন, চর্চা ও প্রশান্তির পথে সুকুন লাইফ',
          style: textTheme.headlineLarge?.copyWith(
            color: SukunColors.nightNavy,
            fontSize: small ? 32 : 46,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'কুরআন, দোয়া, রুকইয়াহ অডিও, নিজের দৈনন্দিন আমল আর সময়মতো '
          'রিমাইন্ডার, সব এক অ্যাপে।',
          style: textTheme.bodyLarge?.copyWith(
            color: SukunColors.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: small ? double.infinity : null,
          child: FilledButton.icon(
            key: const Key('welcome-download-android'),
            onPressed: onDownload,
            style: FilledButton.styleFrom(
              backgroundColor: SukunColors.sukunBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              textStyle: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Android অ্যাপ ডাউনলোড করুন'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          details,
          style: textTheme.bodySmall?.copyWith(color: SukunColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              key: const Key('welcome-copy-link'),
              onPressed: onCopyLink,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('লিংক কপি করুন'),
            ),
            TextButton.icon(
              onPressed: () => context.go('/resources'),
              icon: const Icon(Icons.auto_stories_outlined, size: 18),
              label: const Text('ব্রাউজারেই পাঠ ও অডিও দেখুন'),
            ),
          ],
        ),
      ],
    );
    if (small) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [message, const SizedBox(height: 24), const _InstallSteps()],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 6, child: message),
        const SizedBox(width: 48),
        const Expanded(flex: 5, child: _InstallSteps()),
      ],
    );
  }
}

/// Three plain steps, because most visitors have never installed an APK.
class _InstallSteps extends StatelessWidget {
  const _InstallSteps();

  static const _steps = [
    ('১', 'ডাউনলোড করুন', 'উপরের নীল বাটনে চাপুন। SukunLife.apk ফাইলটি নামবে।'),
    (
      '২',
      'ফাইলটি খুলুন',
      'ফোন অনুমতি চাইলে Settings-এ "এই উৎস থেকে ইনস্টল" চালু করে ফিরে আসুন।',
    ),
    ('৩', 'ইনস্টল করুন', '"ইনস্টল" চাপুন, তারপর অ্যাপ খুলে লগইন করুন।'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SukunColors.nightNavy,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ইনস্টল করবেন যেভাবে',
            style: textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 18),
          for (final step in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white12,
                    child: Text(
                      step.$1,
                      style: const TextStyle(color: SukunColors.saffron),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.$3,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: Colors.white24, height: 20),
          Text(
            'iPhone ব্যবহারকারীরা ব্রাউজারেই app.sukunlife.com ব্যবহার করুন।',
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid();

  static const _items = [
    (
      Icons.notifications_active_outlined,
      'সময়মতো রিমাইন্ডার',
      'আমল, ওষুধ ও অডিওর সময় হলে ফোনেই মনে করিয়ে দেবে।',
    ),
    (
      Icons.today_outlined,
      'দিনের কাজ গুছিয়ে নিন',
      'নিজের পরিকল্পনার কাজ, সময় ও অগ্রগতি সহজে দেখুন।',
    ),
    (
      Icons.menu_book_outlined,
      'ইসলামিক পাঠ ও অডিও',
      'কুরআন, দোয়া, রুকইয়াহ, অডিও ও গাইড খুঁজে পড়ুন।',
    ),
    (
      Icons.favorite_border_rounded,
      'রোগীর ব্যক্তিগত যত্ন',
      'অনুমোদিত কেয়ার প্ল্যান, রিমাইন্ডার ও সম্পন্ন কাজ দেখুন।',
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 900 ? 4 : (width >= 520 ? 2 : 1);
      final cardWidth = (width - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in _items)
            _WelcomeBenefit(
              width: cardWidth,
              icon: item.$1,
              title: item.$2,
              description: item.$3,
            ),
        ],
      );
    },
  );
}

class _WelcomeBenefit extends StatelessWidget {
  const _WelcomeBenefit({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SukunColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SukunColors.mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SukunColors.deepTide, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: SukunColors.nightNavy),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: SukunColors.muted, height: 1.55),
          ),
        ],
      ),
    ),
  );
}

/// Closing call to action with the shareable link spelled out.
class _DownloadBand extends StatelessWidget {
  const _DownloadBand({required this.onDownload, required this.onCopyLink});

  final VoidCallback onDownload;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: SukunColors.mist,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'অন্যদের সাথে শেয়ার করুন',
            style: textTheme.titleLarge?.copyWith(color: SukunColors.nightNavy),
          ),
          const SizedBox(height: 6),
          Text(
            'এই লিংকে সবসময় সর্বশেষ সংস্করণ পাওয়া যাবে।',
            style: textTheme.bodyMedium?.copyWith(color: SukunColors.nightNavy),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SukunColors.border),
            ),
            child: SelectableText(
              publicAndroidApkLink,
              style: textTheme.bodySmall?.copyWith(color: SukunColors.deepTide),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onDownload,
                style: FilledButton.styleFrom(
                  backgroundColor: SukunColors.sukunBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('ডাউনলোড করুন'),
              ),
              OutlinedButton.icon(
                onPressed: onCopyLink,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('লিংক কপি করুন'),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('ব্রাউজারে লগইন করুন'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
