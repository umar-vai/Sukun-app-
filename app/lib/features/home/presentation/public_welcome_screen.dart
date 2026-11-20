import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sukun_life/core/updates/android_release.dart';
import 'package:sukun_life/core/updates/android_update_service.dart';

/// The approved native release URL is supplied at web build time. An empty or
/// non-HTTPS value keeps the download action closed until a signed APK exists.
const androidApkUrl = String.fromEnvironment('ANDROID_APK_URL');

// The first signed APK is published and `/updates/android.json` is enabled, so
// the landing reads that manifest by default and links the latest approved
// build. Set ENABLE_PUBLIC_APK_DOWNLOAD=false to close the button again.
const publicApkDownloadEnabled = bool.fromEnvironment(
  'ENABLE_PUBLIC_APK_DOWNLOAD',
  defaultValue: true,
);

/// Test seam: widget tests set this to `false` so the landing does not start
/// the manifest request (and its 9 second timer) unless a test opts in.
@visibleForTesting
bool? debugPublicApkDownloadOverride;

Uri? approvedAndroidApkUri(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && isApprovedApkUri(uri) ? uri : null;
}

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
    final enabled = debugPublicApkDownloadOverride ?? publicApkDownloadEnabled;
    _publishedRelease = enabled
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

  Future<void> _downloadAndroid(BuildContext context, Uri? uri) async {
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ডাউনলোড লিংক খোলা যাচ্ছে না।')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AndroidRelease?>(
      future: _publishedRelease,
      builder: (context, snapshot) {
        final uri =
            snapshot.data?.apkUrl ?? approvedAndroidApkUri(androidApkUrl);
        final canDownload = uri != null;
        final small = MediaQuery.sizeOf(context).width < 700;
        return Scaffold(
          backgroundColor: SukunColors.canvas,
          body: SafeArea(
            child: ListView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: small ? 20 : 34,
                        vertical: small ? 18 : 26,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _WelcomeHeader(),
                          SizedBox(height: small ? 22 : 40),
                          _WelcomeHero(small: small),
                          SizedBox(height: small ? 34 : 64),
                          Text(
                            'সুকুন লাইফে যা পাবেন',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: SukunColors.nightNavy),
                          ),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = constraints.maxWidth < 700
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 36) / 3;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 12,
                                children: [
                                  _WelcomeBenefit(
                                    width: cardWidth,
                                    icon: Icons.today_outlined,
                                    title: 'দিনের কাজ গুছিয়ে নিন',
                                    description: 'নিজের পরিকল্পনার কাজ, সময় ও অগ্রগতি সহজে দেখুন।',
                                  ),
                                  _WelcomeBenefit(
                                    width: cardWidth,
                                    icon: Icons.menu_book_outlined,
                                    title: 'ইসলামিক পাঠ ও অডিও',
                                    description: 'কুরআন, দোয়া, রুকইয়াহ, অডিও ও গাইড খুঁজে পড়ুন।',
                                  ),
                                  _WelcomeBenefit(
                                    width: cardWidth,
                                    icon: Icons.favorite_border_rounded,
                                    title: 'রোগীর ব্যক্তিগত যত্ন',
                                    description: 'অনুমোদিত কেয়ার প্ল্যান, রিমাইন্ডার ও সম্পন্ন কাজ দেখুন।',
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 44),
                          _WelcomeAccess(
                            canDownload: canDownload,
                            onDownload: () => _downloadAndroid(context, uri),
                          ),
                          const SizedBox(height: 34),
                          Text(
                            'সুকুন লাইফ · আপনার যত্নের পথে সহযাত্রী',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: SukunColors.muted),
                          ),
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
      spacing: 8,
      children: [
        TextButton(
          onPressed: () => context.go('/resources'),
          child: const Text('পাঠ ও অডিও'),
        ),
        TextButton(
          onPressed: () => context.go('/announcements'),
          child: const Text('নোটিশ'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('লগইন'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 700
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const SukunLifeLogo(height: 45), links],
            )
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [const SukunLifeLogo(height: 45), links],
            ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.small});
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: SukunColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: SukunColors.saffron,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'আপনার শান্ত, গুছানো দিনের সঙ্গী',
                  style: TextStyle(
                    color: SukunColors.deepTide,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'যত্ন, চর্চা ও প্রশান্তির পথে সুকুন লাইফ',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: SukunColors.nightNavy,
            fontSize: small ? 32 : 48,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'কুরআন, দোয়া, রুকইয়াহ অডিও ও নিজের দৈনন্দিন আমল এক জায়গায়।',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: SukunColors.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        if (small)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/resources'),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('পাঠ ও অডিও দেখুন'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(Icons.login_rounded),
                label: const Text('লগইন'),
              ),
            ],
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/resources'),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('পাঠ ও অডিও দেখুন'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(Icons.login_rounded),
                label: const Text('লগইন'),
              ),
            ],
          ),
      ],
    );
    final panel = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SukunColors.mist,
        borderRadius: BorderRadius.circular(small ? 28 : 36),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -70,
            child: _SoftCircle(size: small ? 190 : 300),
          ),
          Positioned(
            right: small ? 40 : 160,
            bottom: -90,
            child: _SoftCircle(size: small ? 140 : 220),
          ),
          Padding(
            padding: EdgeInsets.all(small ? 22 : 44),
            child: small
                ? message
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 6, child: message),
                      const SizedBox(width: 48),
                      const Expanded(flex: 4, child: _CareJourneyCard()),
                    ],
                  ),
          ),
        ],
      ),
    );
    if (!small) return panel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [panel, const SizedBox(height: 16), const _CareJourneyCard()],
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.55),
    ),
  );
}

class _CareJourneyCard extends StatelessWidget {
  const _CareJourneyCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: SukunColors.nightNavy,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.spa_outlined, color: SukunColors.saffron, size: 34),
        const SizedBox(height: 28),
        Text(
          'আপনার যত্নের পথ',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 18),
        for (final step in const [
          ('০১', 'পরিকল্পনা বুঝুন'),
          ('০২', 'প্রতিদিনের কাজ অনুসরণ করুন'),
          ('০৩', 'অগ্রগতি দেখুন'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white12,
                  child: Text(
                    step.$1,
                    style: const TextStyle(color: SukunColors.saffron),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.$2,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'আপনার ব্যক্তিগত পরিকল্পনা নিরাপদে সংরক্ষিত।',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SukunColors.border),
      ),
      // Title-only card (owner request 2026-11-12); [description] is kept
      // for screen readers.
      child: Semantics(
        label: description,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: SukunColors.mist,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: SukunColors.deepTide, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SukunColors.nightNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WelcomeAccess extends StatelessWidget {
  const _WelcomeAccess({required this.canDownload, required this.onDownload});
  final bool canDownload;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: SukunColors.mist,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 22,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'আপনার পছন্দের জায়গা থেকে শুরু করুন',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: SukunColors.nightNavy),
            ),
            const SizedBox(height: 5),
            const Text(
              'ব্রাউজারে ব্যবহার করুন, অথবা Android অ্যাপ নিন।',
              style: TextStyle(color: SukunColors.nightNavy),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('ওয়েব অ্যাপ খুলুন'),
            ),
            _DownloadAction(canDownload: canDownload, onDownload: onDownload),
          ],
        ),
      ],
    ),
  );
}

class _DownloadAction extends StatelessWidget {
  const _DownloadAction({required this.canDownload, required this.onDownload});
  final bool canDownload;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton.icon(
        onPressed: canDownload ? onDownload : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: SukunColors.deepTide,
          disabledForegroundColor: SukunColors.muted,
        ),
        icon: const Icon(Icons.android_rounded),
        label: Text(
          canDownload ? 'Android অ্যাপ ডাউনলোড' : 'Android অ্যাপ শীঘ্রই',
        ),
      ),
      if (!canDownload)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'নিরাপদ APK প্রকাশের পর ডাউনলোড চালু হবে।',
            style: TextStyle(color: SukunColors.muted, fontSize: 12),
          ),
        ),
    ],
  );
}
