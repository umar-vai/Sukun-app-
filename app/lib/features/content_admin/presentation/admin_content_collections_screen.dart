import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:uuid/uuid.dart';

class AdminContentCollectionsScreen extends ConsumerStatefulWidget {
  const AdminContentCollectionsScreen({super.key});

  @override
  ConsumerState<AdminContentCollectionsScreen> createState() =>
      _AdminContentCollectionsScreenState();
}

class _AdminContentCollectionsScreenState
    extends ConsumerState<AdminContentCollectionsScreen> {
  late Future<(List<AdminContentCollection>, List<AdminContentItem>)> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = _load();
  }

  Future<(List<AdminContentCollection>, List<AdminContentItem>)> _load() async {
    final repository = ref.read(contentAdminRepositoryProvider);
    final collectionsFuture = repository.listCollections();
    final contentFuture = repository.listContent();
    final collections = await collectionsFuture;
    final content = await contentFuture;
    final ayat =
        content
            .where((item) => item.type == 'quran' && item.status == 'published')
            .toList(growable: false)
          ..sort((a, b) {
            final surah = (a.surahNumber ?? 999).compareTo(
              b.surahNumber ?? 999,
            );
            return surah != 0
                ? surah
                : (a.ayahNumber ?? 9999).compareTo(b.ayahNumber ?? 9999);
          });
    return (collections, ayat);
  }

  Future<void> _openEditor(
    List<AdminContentItem> ayat, [
    AdminContentCollection? collection,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CollectionEditorDialog(
        repository: ref.read(contentAdminRepositoryProvider),
        ayat: ayat,
        collection: collection,
      ),
    );
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _transition(
    AdminContentCollection collection,
    String transition,
  ) async {
    try {
      await ref
          .read(contentAdminRepositoryProvider)
          .transitionCollection(
            collectionId: collection.id,
            transition: transition,
            requestId: const Uuid().v4(),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Collection ${transition}d.')));
        setState(_reload);
      }
    } on ContentAdminException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayat collections')),
      floatingActionButton:
          FutureBuilder<(List<AdminContentCollection>, List<AdminContentItem>)>(
            future: _data,
            builder: (context, snapshot) => FloatingActionButton.extended(
              onPressed: snapshot.hasData
                  ? () => _openEditor(snapshot.data!.$2)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('New collection'),
            ),
          ),
      body: FutureBuilder<(List<AdminContentCollection>, List<AdminContentItem>)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading collections');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(_reload),
            );
          }
          final collections = snapshot.data!.$1;
          final ayat = snapshot.data!.$2;
          if (collections.isEmpty) {
            return AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'No Ayat collections yet',
              message: ayat.isEmpty
                  ? 'Publish Qur’an Ayat before creating a collection.'
                  : 'Create a selected-Ayat or Ruqyah-Ayat collection.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: collections.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SukunPageIntro(
                    eyebrow: 'Canonical reuse',
                    title: 'Ayat collections',
                    subtitle: 'Curate selected and Ruqyah sets without duplicating sourced Qur’an text.',
                    trailing: SukunIconBadge(
                      icon: Icons.collections_bookmark_outlined,
                      size: 54,
                    ),
                  ),
                );
              }
              final collection = collections[index - 1];
              return SukunSurface(
                radius: 20,
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const SukunIconBadge(icon: Icons.bookmarks_outlined),
                  title: Text(collection.title),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${_label(collection.type)} · ${collection.contentItemIds.length} Ayat',
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SukunStatusPill(
                        label: _label(collection.status),
                        tone: collection.status == 'published'
                            ? SukunStatusTone.success
                            : SukunStatusTone.neutral,
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _openEditor(ayat, collection);
                          } else {
                            _transition(collection, action);
                          }
                        },
                        itemBuilder: (context) => [
                          if (collection.status == 'draft') ...[
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'publish',
                              child: Text('Publish'),
                            ),
                          ],
                          if (collection.status == 'published')
                            const PopupMenuItem(
                              value: 'unpublish',
                              child: Text('Unpublish'),
                            ),
                          if (collection.status != 'archived')
                            const PopupMenuItem(
                              value: 'archive',
                              child: Text('Archive'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CollectionEditorDialog extends StatefulWidget {
  const _CollectionEditorDialog({
    required this.repository,
    required this.ayat,
    this.collection,
  });

  final ContentAdminRepository repository;
  final List<AdminContentItem> ayat;
  final AdminContentCollection? collection;

  @override
  State<_CollectionEditorDialog> createState() =>
      _CollectionEditorDialogState();
}

class _CollectionEditorDialogState extends State<_CollectionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _titleBnController;
  late final TextEditingController _slugController;
  late final TextEditingController _summaryController;
  late String _type;
  late String _visibility;
  late Set<String> _selectedIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final collection = widget.collection;
    _titleController = TextEditingController(text: collection?.title);
    _titleBnController = TextEditingController(text: collection?.titleBn);
    _slugController = TextEditingController(text: collection?.slug);
    _summaryController = TextEditingController(text: collection?.summary);
    _type = collection?.type ?? 'selected_ayat';
    _visibility = collection?.visibility ?? 'public';
    _selectedIds = collection?.contentItemIds.toSet() ?? <String>{};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleBnController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final input = SaveContentCollectionInput(
      collectionId: widget.collection?.id,
      type: _type,
      title: _titleController.text,
      titleBn: _titleBnController.text,
      slug: _slugController.text,
      summary: _summaryController.text,
      visibility: _visibility,
      contentItemIds: widget.ayat
          .where((item) => _selectedIds.contains(item.id))
          .map((item) => item.id)
          .toList(growable: false),
      requestId: const Uuid().v4(),
    );
    final validation = input.validate();
    if (validation != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validation)));
      return;
    }
    try {
      await widget.repository.saveCollection(input);
      if (mounted) Navigator.of(context).pop(true);
    } on ContentAdminException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SukunPageIntro(
                  eyebrow: 'Collection editor',
                  title: widget.collection == null
                      ? 'New Ayat collection'
                      : 'Edit collection',
                  subtitle: 'Select published, sourced canonical Ayat and set the approved audience.',
                  trailing: const SukunIconBadge(
                    icon: Icons.collections_bookmark_outlined,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SukunChoiceField<String>(
                          value: _type,
                          label: 'Collection type',
                          placeholder: 'Choose a type',
                          options: const [
                            SukunChoiceOption(
                              value: 'selected_ayat',
                              title: 'Selected Ayat',
                              description: 'A curated reading collection.',
                              icon: Icons.bookmarks_outlined,
                            ),
                            SukunChoiceOption(
                              value: 'ruqyah_ayat',
                              title: 'Ruqyah Ayat',
                              description:
                                  'Approved Ayat grouped for Ruqyah browsing.',
                              icon: Icons.health_and_safety_outlined,
                            ),
                          ],
                          onChanged: (value) => setState(() => _type = value),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Title is required.'
                              : null,
                        ),
                        TextFormField(
                          controller: _titleBnController,
                          decoration: const InputDecoration(
                            labelText: 'Bangla title',
                          ),
                        ),
                        TextFormField(
                          controller: _slugController,
                          decoration: const InputDecoration(labelText: 'Slug'),
                          validator: (value) =>
                              value == null ||
                                  !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
                                      .hasMatch(value)
                              ? 'Use lowercase words separated by hyphens.'
                              : null,
                        ),
                        TextFormField(
                          controller: _summaryController,
                          decoration: const InputDecoration(
                            labelText: 'Summary',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SukunChoiceField<String>(
                          value: _visibility,
                          label: 'Visibility',
                          placeholder: 'Choose the audience',
                          options: const [
                            SukunChoiceOption(
                              value: 'public',
                              title: 'Public',
                              description: 'Available to guests and signed-in users after publishing.',
                              icon: Icons.public_rounded,
                            ),
                            SukunChoiceOption(
                              value: 'patient_only',
                              title: 'Patient only',
                              description:
                                  'Restricted to authenticated patients.',
                              icon: Icons.person_outline_rounded,
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _visibility = value),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Published canonical Ayat (${_selectedIds.length} selected)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (widget.ayat.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('No published Ayat are available.'),
                          )
                        else
                          for (final ayah in widget.ayat)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _selectedIds.contains(ayah.id),
                              title: Text(ayah.titleBn ?? ayah.title),
                              subtitle: Text(
                                'Surah ${ayah.surahNumber ?? '-'} • Ayah ${ayah.ayahNumber ?? '-'} • ${_label(ayah.status)}',
                              ),
                              onChanged: (selected) => setState(() {
                                if (selected == true) {
                                  _selectedIds.add(ayah.id);
                                } else {
                                  _selectedIds.remove(ayah.id);
                                }
                              }),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save draft'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _label(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
