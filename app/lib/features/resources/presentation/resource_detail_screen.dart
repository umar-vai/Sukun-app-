import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/media/external_resource_launcher.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';
import 'package:sukun_life/features/resources/presentation/youtube_player_screen.dart';

class ResourceDetailScreen extends ConsumerStatefulWidget {
  const ResourceDetailScreen({super.key, required this.resourceId});

  final String resourceId;

  @override
  ConsumerState<ResourceDetailScreen> createState() =>
      _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends ConsumerState<ResourceDetailScreen> {
  late Future<ContentResource?> _resource;

  @override
  void initState() {
    super.initState();
    _resource = _load();
  }

  Future<ContentResource?> _load() =>
      ref.read(resourcesRepositoryProvider).getResource(widget.resourceId);

  void _reload() {
    setState(() {
      _resource = _load();
    });
  }

  Future<void> _openMedia(ContentResource resource) async {
    final target = resolveResourceMedia(resource.linkedResource);
    if (target == null) {
      _showError('This resource does not have a valid secure media link.');
      return;
    }
    if (target.kind == ResourceMediaKind.audio) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) =>
              AudioPlayerScreen(resource: resource.linkedResource),
        ),
      );
      return;
    }
    if (target.kind == ResourceMediaKind.youtube) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) =>
              SukunYoutubePlayerScreen(resource: resource.linkedResource),
        ),
      );
      return;
    }
    try {
      await ref.read(resourceLauncherProvider).open(resource.linkedResource);
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Islamic Resource')),
      body: FutureBuilder<ContentResource?>(
        future: _resource,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Opening resource');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final resource = snapshot.data;
          if (resource == null) {
            return const AppEmptyState(
              title: 'Resource unavailable',
              message: 'This resource is not published or is not assigned to your account.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  SukunStatusPill(
                    label: _typeLabel(resource.type),
                    tone: SukunStatusTone.brand,
                  ),
                  if (resource.referenceText?.isNotEmpty == true ||
                      resource.sourceReference?.isNotEmpty == true)
                    const SukunStatusPill(
                      label: 'SOURCE REFERENCED',
                      tone: SukunStatusTone.success,
                      icon: Icons.verified_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SukunPageIntro(
                title: resource.titleBn?.isNotEmpty == true
                    ? resource.titleBn!
                    : resource.title,
                subtitle: resource.titleBn?.isNotEmpty == true
                    ? resource.title
                    : resource.summary,
              ),
              if (resource.titleBn?.isNotEmpty == true)
                const SizedBox(height: 4),
              _Section(
                label: 'Summary',
                value: resource.titleBn?.isNotEmpty == true
                    ? resource.summary
                    : null,
              ),
              _Section(
                label: 'Arabic',
                value: resource.arabicText,
                textAlign: TextAlign.right,
                canonical: true,
              ),
              _Section(
                label: 'Bangla',
                value: resource.banglaText,
                bangla: true,
              ),
              _Section(
                label: 'Transliteration',
                value: resource.transliteration,
              ),
              _Section(label: 'Translation', value: resource.translation),
              _Section(label: 'Guide', value: resource.body),
              _Section(
                label: 'Reference',
                value: resource.referenceText ?? resource.sourceReference,
              ),
              _Section(label: 'Rights & licensing', value: resource.rightsNote),
              if (resource.linkedResource.canOpen) ...[
                const SizedBox(height: 24),
                SukunSurface(
                  tone: SukunSurfaceTone.navy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Continue with this resource',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: SukunColors.nightNavy,
                        ),
                        onPressed: () => _openMedia(resource),
                        icon: Icon(_openIcon(resource.mediaSourceType)),
                        label: Text(_openLabel(resource.mediaSourceType)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    this.value,
    this.textAlign,
    this.canonical = false,
    this.bangla = false,
  });

  final String label;
  final String? value;
  final TextAlign? textAlign;
  final bool canonical;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    if (value?.trim().isNotEmpty != true) return const SizedBox.shrink();
    final base = canonical
        ? SukunTypography.canonicalReligiousText(
            textStyle: Theme.of(context).textTheme.headlineSmall,
          ).copyWith(height: 2)
        : bangla
        ? SukunTypography.banglaBody(
            textStyle: Theme.of(context).textTheme.bodyLarge,
          ).copyWith(height: 1.75)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SukunSurface(
        tone: canonical ? SukunSurfaceTone.soft : SukunSurfaceTone.white,
        showBorder: !canonical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SukunColors.deepTide,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: canonical ? TextDirection.rtl : TextDirection.ltr,
              child: SelectableText(value!, textAlign: textAlign, style: base),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(String type) => type
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

String _openLabel(String? mediaType) => switch (mediaType) {
  'direct_audio_url' => 'Play audio',
  'youtube' => 'Play video',
  'direct_video_url' => 'Open video in device player',
  'external_pdf' => 'Open PDF in device viewer',
  _ => 'Open external resource',
};

IconData _openIcon(String? mediaType) => switch (mediaType) {
  'direct_audio_url' => Icons.play_arrow_rounded,
  'youtube' || 'direct_video_url' => Icons.ondemand_video_outlined,
  'external_pdf' => Icons.picture_as_pdf_outlined,
  _ => Icons.open_in_new,
};
