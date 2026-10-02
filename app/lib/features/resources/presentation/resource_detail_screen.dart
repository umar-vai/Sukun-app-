import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/media/external_resource_launcher.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

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

  void _reload() => setState(() => _resource = _load());

  Future<void> _openExternal(ContentResource resource) async {
    try {
      await ref.read(resourceLauncherProvider).open(resource.linkedResource);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
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
                  Chip(label: Text(_typeLabel(resource.type))),
                  if (resource.referenceText?.isNotEmpty == true ||
                      resource.sourceReference?.isNotEmpty == true)
                    const Chip(label: Text('Source referenced')),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                resource.titleBn?.isNotEmpty == true
                    ? resource.titleBn!
                    : resource.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (resource.titleBn?.isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(resource.title),
              ],
              _Section(label: 'Summary', value: resource.summary),
              _Section(
                label: 'Arabic',
                value: resource.arabicText,
                textAlign: TextAlign.right,
              ),
              _Section(label: 'Bangla', value: resource.banglaText),
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
              if (resource.linkedResource.canOpen) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _openExternal(resource),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(_openLabel(resource.mediaSourceType)),
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
  const _Section({required this.label, this.value, this.textAlign});

  final String label;
  final String? value;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (value?.trim().isNotEmpty != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 7),
          SelectableText(value!, textAlign: textAlign),
        ],
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
  'direct_audio_url' => 'Open audio',
  'direct_video_url' || 'youtube' => 'Open video',
  'external_pdf' => 'Open PDF',
  _ => 'Open external resource',
};
