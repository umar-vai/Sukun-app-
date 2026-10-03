import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:uuid/uuid.dart';

class AdminContentEditorScreen extends ConsumerStatefulWidget {
  const AdminContentEditorScreen({super.key, this.contentItemId});

  final String? contentItemId;

  @override
  ConsumerState<AdminContentEditorScreen> createState() =>
      _AdminContentEditorScreenState();
}

class _AdminContentEditorScreenState
    extends ConsumerState<AdminContentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late Future<_EditorData> _data;
  String _type = 'dua';
  String _visibility = 'staff_only';
  String? _categoryId;
  String? _parentContentId;
  String? _mediaSourceType;
  bool _populated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  Future<_EditorData> _load() async {
    final repository = ref.read(contentAdminRepositoryProvider);
    final results = await Future.wait([
      repository.listCategories(),
      repository.listContent(),
      if (widget.contentItemId != null)
        repository.getContent(widget.contentItemId!),
    ]);
    return _EditorData(
      categories: results[0] as List<ContentCategory>,
      allContent: results[1] as List<AdminContentItem>,
      item: widget.contentItemId == null
          ? null
          : results[2] as AdminContentItem?,
    );
  }

  void _populate(AdminContentItem? item) {
    if (_populated) return;
    _populated = true;
    if (item == null) return;
    _type = item.type;
    _visibility = item.visibility;
    _categoryId = item.categoryId;
    _parentContentId = item.parentContentId;
    _mediaSourceType = item.mediaSourceType;
    final values = <String, Object?>{
      'title': item.title,
      'titleBn': item.titleBn,
      'slug': item.slug,
      'summary': item.summary,
      'body': item.body,
      'arabicText': item.arabicText,
      'banglaText': item.banglaText,
      'transliteration': item.transliteration,
      'translation': item.translation,
      'referenceText': item.referenceText,
      'sourceType': item.sourceType,
      'sourceReference': item.sourceReference,
      'sourceUrl': item.sourceUrl,
      'sourceEdition': item.sourceEdition,
      'translationSource': item.translationSource,
      'surahNumber': item.surahNumber,
      'surahName': item.surahName,
      'surahNameBn': item.surahNameBn,
      'ayahNumber': item.ayahNumber,
      'ayahEndNumber': item.ayahEndNumber,
      'collectionName': item.collectionName,
      'bookName': item.bookName,
      'hadithNumber': item.hadithNumber,
      'narrator': item.narrator,
      'grade': item.grade,
      'author': item.author,
      'publisher': item.publisher,
      'chapterNumber': item.chapterNumber,
      'languageCode': item.languageCode,
      'rightsNote': item.rightsNote,
      'thumbnailUrl': item.thumbnailUrl,
      'mediaUrl': item.mediaUrl,
      'youtubeVideoId': item.youtubeVideoId,
    };
    for (final entry in values.entries) {
      _controller(entry.key).text = entry.value?.toString() ?? '';
    }
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    final input = _input(status);
    final error = input.validate();
    if (error != null) {
      _show(error);
      return;
    }
    setState(() => _saving = true);
    try {
      final item = await ref
          .read(contentAdminRepositoryProvider)
          .saveContent(input);
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (error) {
      if (mounted) _show(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  SaveContentInput _input(String status) => SaveContentInput(
    contentItemId: widget.contentItemId,
    type: _type,
    categoryId: _categoryId,
    parentContentId: _type == 'book_chapter' ? _parentContentId : null,
    title: _text('title'),
    titleBn: _nullable('titleBn'),
    slug: _text('slug'),
    summary: _nullable('summary'),
    body: _nullable('body'),
    arabicText: _nullable('arabicText'),
    banglaText: _nullable('banglaText'),
    transliteration: _nullable('transliteration'),
    translation: _nullable('translation'),
    referenceText: _nullable('referenceText'),
    sourceType: _nullable('sourceType'),
    sourceReference: _nullable('sourceReference'),
    sourceUrl: _nullable('sourceUrl'),
    sourceEdition: _nullable('sourceEdition'),
    translationSource: _nullable('translationSource'),
    surahNumber: _integer('surahNumber'),
    surahName: _nullable('surahName'),
    surahNameBn: _nullable('surahNameBn'),
    ayahNumber: _integer('ayahNumber'),
    ayahEndNumber: _integer('ayahEndNumber'),
    collectionName: _nullable('collectionName'),
    bookName: _nullable('bookName'),
    hadithNumber: _nullable('hadithNumber'),
    narrator: _nullable('narrator'),
    grade: _nullable('grade'),
    author: _nullable('author'),
    publisher: _nullable('publisher'),
    chapterNumber: _integer('chapterNumber'),
    languageCode: _nullable('languageCode'),
    rightsNote: _nullable('rightsNote'),
    thumbnailUrl: _nullable('thumbnailUrl'),
    mediaSourceType: _mediaSourceType,
    mediaUrl: _nullable('mediaUrl'),
    youtubeVideoId: _nullable('youtubeVideoId'),
    visibility: _visibility,
    status: status,
    requestId: const Uuid().v4(),
  );

  String _text(String key) => _controller(key).text.trim();
  String? _nullable(String key) {
    final value = _text(key);
    return value.isEmpty ? null : value;
  }

  int? _integer(String key) => int.tryParse(_text(key));

  void _show(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addCategory(_EditorData data) async {
    final name = TextEditingController();
    final slug = TextEditingController();
    final nameBn = TextEditingController();
    final created = await showDialog<ContentCategory>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SukunIconBadge(icon: Icons.create_new_folder_outlined),
                  const SizedBox(height: 16),
                  Text(
                    'Add category',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a reusable taxonomy label for the Resources library.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: SukunColors.muted),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name *'),
                  ),
                  TextField(
                    controller: nameBn,
                    decoration: const InputDecoration(labelText: 'Bangla name'),
                  ),
                  TextField(
                    controller: slug,
                    decoration: const InputDecoration(
                      labelText: 'Slug *',
                      hintText: 'dua-morning',
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            try {
                              final result = await ref
                                  .read(contentAdminRepositoryProvider)
                                  .saveCategory(
                                    name: name.text,
                                    nameBn: nameBn.text,
                                    slug: slug.text,
                                    requestId: const Uuid().v4(),
                                  );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, result);
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                              }
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    name.dispose();
    slug.dispose();
    nameBn.dispose();
    if (created == null || !mounted) return;
    setState(() {
      _categoryId = created.id;
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contentItemId == null ? 'New resource' : 'Edit resource',
        ),
      ),
      body: FutureBuilder<_EditorData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Preparing content editor');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _data = _load()),
            );
          }
          final data = snapshot.data!;
          _populate(data.item);
          if (widget.contentItemId != null && data.item == null) {
            return const AppEmptyState(
              title: 'Resource not found',
              message: 'This content item may have been archived or removed.',
              icon: Icons.search_off_rounded,
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                SukunPageIntro(
                  eyebrow: 'Content workspace',
                  title: widget.contentItemId == null
                      ? 'Create a resource'
                      : 'Refine this resource',
                  subtitle: 'Build one canonical, source-aware item that can be reused across browsing and care plans.',
                  trailing: const SukunIconBadge(
                    icon: Icons.auto_stories_outlined,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 20),
                const SukunSurface(
                  tone: SukunSurfaceTone.warning,
                  showBorder: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: SukunColors.deepTide,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Canonical Qur’an and Hadith text must be entered from an approved source, independently reviewed, and verified before publishing.',
                        ),
                      ),
                    ],
                  ),
                ),
                const _SectionTitle(
                  title: 'Resource identity',
                  subtitle: 'One canonical resource can be reused publicly and in care plans.',
                ),
                SukunChoiceField<String>(
                  key: ValueKey(_type),
                  label: 'Content type *',
                  placeholder: 'Choose content type',
                  value: _type,
                  options: [
                    for (final type in contentTypes)
                      SukunChoiceOption(
                        value: type,
                        title: _label(type),
                        description: _contentTypeDescription(type),
                        icon: _contentTypeIcon(type),
                      ),
                  ],
                  onChanged: (value) => setState(() => _type = value),
                ),
                _field('title', 'English / primary title *', required: true),
                _field('titleBn', 'Bangla title'),
                _field(
                  'slug',
                  'Slug *',
                  required: true,
                  hint: 'morning-adhkar',
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: SukunChoiceField<String>(
                        value: _categoryId ?? '',
                        label: 'Category',
                        placeholder: 'Choose category',
                        options: [
                          const SukunChoiceOption(
                            value: '',
                            title: 'No category',
                            description:
                                'Keep this resource outside a taxonomy group.',
                          ),
                          for (final category in data.categories.where(
                            (c) => c.isActive,
                          ))
                            SukunChoiceOption(
                              value: category.id,
                              title: category.name,
                              description: category.nameBn,
                            ),
                        ],
                        onChanged: (value) => setState(
                          () => _categoryId = value.isEmpty ? null : value,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Add category',
                      onPressed: () => _addCategory(data),
                      icon: const Icon(Icons.create_new_folder_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SukunChoiceField<String>(
                  value: _visibility,
                  label: 'Visibility *',
                  placeholder: 'Choose who may see this',
                  options: [
                    for (final visibility in resourceVisibilities)
                      SukunChoiceOption(
                        value: visibility,
                        title: _label(visibility),
                        description: _visibilityDescription(visibility),
                        icon: _visibilityIcon(visibility),
                      ),
                  ],
                  onChanged: (value) => setState(() => _visibility = value),
                ),
                if (_type == 'book_chapter') ...[
                  const SizedBox(height: 12),
                  SukunChoiceField<String>(
                    value: _parentContentId,
                    label: 'Parent book *',
                    placeholder: 'Choose a parent book',
                    options: [
                      for (final book in data.allContent.where(
                        (item) => item.type == 'book',
                      ))
                        SukunChoiceOption(
                          value: book.id,
                          title: book.title,
                          description: book.titleBn,
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _parentContentId = value),
                  ),
                  _field('chapterNumber', 'Chapter number *', numeric: true),
                ],
                const _SectionTitle(
                  title: 'Content',
                  subtitle: 'Canonical religious text must be copied only from an approved source.',
                ),
                _field('summary', 'Summary', lines: 3),
                _field('body', 'Body / article text', lines: 8),
                if (_type == 'quran' || _type == 'hadith') ...[
                  _field('arabicText', 'Verified Arabic text', lines: 6),
                  _field(
                    'banglaText',
                    'Approved Bangla text / translation',
                    lines: 6,
                  ),
                  _field('transliteration', 'Transliteration', lines: 4),
                  _field('translation', 'Additional translation', lines: 4),
                ],
                _field('referenceText', 'Display reference'),
                if (_type == 'quran') ...[
                  const _SectionTitle(title: "Qur'an reference"),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'surahNumber',
                          'Surah no. *',
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'ayahNumber',
                          'Start Ayah *',
                          numeric: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'ayahEndNumber',
                          'End Ayah',
                          numeric: true,
                        ),
                      ),
                    ],
                  ),
                  _field('surahName', 'Surah name'),
                  _field('surahNameBn', 'Bangla Surah name'),
                ],
                if (_type == 'hadith') ...[
                  const _SectionTitle(title: 'Hadith reference'),
                  _field('collectionName', 'Collection *'),
                  _field('bookName', 'Book *'),
                  _field('hadithNumber', 'Hadith number *'),
                  _field('narrator', 'Narrator'),
                  _field('grade', 'Approved grade / classification'),
                ],
                const _SectionTitle(
                  title: 'Source and verification',
                  subtitle: 'AI is never an approved source for canonical Qur’an or Hadith text.',
                ),
                _field(
                  'sourceType',
                  'Source type',
                  hint: 'official_api or licensed_publication',
                ),
                _field('sourceReference', 'Source reference'),
                _field('sourceEdition', 'Edition / API dataset version'),
                _field('sourceUrl', 'Source URL (HTTPS)'),
                _field('translationSource', 'Bangla translation source'),
                _field('languageCode', 'Language code', hint: 'bn-BD'),
                if ({
                  'book',
                  'book_chapter',
                  'article',
                  'guide',
                  'pdf',
                }.contains(_type)) ...[
                  _field('author', 'Author'),
                  _field('publisher', 'Publisher'),
                ],
                _field('rightsNote', 'Rights / licensing note', lines: 3),
                const _SectionTitle(title: 'External media'),
                SukunChoiceField<String>(
                  value: _mediaSourceType ?? '',
                  label: 'Media type',
                  placeholder: 'Choose external media',
                  options: [
                    const SukunChoiceOption(
                      value: '',
                      title: 'No external media',
                      description: 'This resource is text-only.',
                      icon: Icons.article_outlined,
                    ),
                    for (final type in mediaSourceTypes)
                      SukunChoiceOption(
                        value: type,
                        title: _label(type),
                        description: _mediaDescription(type),
                        icon: _mediaIcon(type),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _mediaSourceType = value.isEmpty ? null : value,
                  ),
                ),
                if (_mediaSourceType == 'youtube')
                  _field('youtubeVideoId', 'YouTube video ID *')
                else if (_mediaSourceType != null)
                  _field('mediaUrl', 'External media URL (HTTPS) *'),
                _field('thumbnailUrl', 'Thumbnail URL (HTTPS)'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save('draft'),
                        child: const Text('Save draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _save('review'),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.rate_review_outlined),
                        label: const Text('Submit for review'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    int lines = 1,
    bool required = false,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: _controller(key),
      maxLines: lines,
      keyboardType: numeric
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required.'
                : null
          : null,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

class _EditorData {
  const _EditorData({
    required this.categories,
    required this.allContent,
    required this.item,
  });

  final List<ContentCategory> categories;
  final List<AdminContentItem> allContent;
  final AdminContentItem? item;
}

String _label(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

String _contentTypeDescription(String value) => switch (value) {
  'quran' => 'Verified Surah and Ayah text with source metadata.',
  'hadith' => 'Collection, book, number, grade, and approved source.',
  'dua' => 'Dua or daily supplication with translation and reference.',
  'azkar' => 'Categorised remembrance for a specific moment or routine.',
  'ruqyah' => 'Approved Ruqyah guidance, recitation, or linked media.',
  'book' => 'A reusable book record with chapters or external PDF.',
  'book_chapter' => 'A structured chapter connected to a canonical book.',
  'article' => 'An authored educational article or guide.',
  'audio' => 'A direct, licensed external audio resource.',
  'video' => 'An external video or YouTube resource.',
  'pdf' => 'An external document with ownership metadata.',
  _ => 'A reusable Sukun Life resource.',
};

IconData _contentTypeIcon(String value) => switch (value) {
  'quran' => Icons.menu_book_rounded,
  'hadith' => Icons.format_quote_rounded,
  'dua' || 'azkar' => Icons.auto_awesome_rounded,
  'ruqyah' => Icons.health_and_safety_outlined,
  'book' || 'book_chapter' || 'pdf' => Icons.library_books_outlined,
  'audio' => Icons.headphones_rounded,
  'video' => Icons.play_circle_outline_rounded,
  _ => Icons.article_outlined,
};

String _visibilityDescription(String value) => switch (value) {
  'public' => 'Visible to guests and signed-in users after publishing.',
  'patient_only' => 'Available only to authenticated patients.',
  'assigned_only' => 'Visible only when linked to a patient’s care plan.',
  'staff_only' => 'Restricted to verified Super Admin users.',
  _ => 'Apply the approved audience rule.',
};

IconData _visibilityIcon(String value) => switch (value) {
  'public' => Icons.public_rounded,
  'patient_only' => Icons.person_outline_rounded,
  'assigned_only' => Icons.assignment_ind_outlined,
  _ => Icons.admin_panel_settings_outlined,
};

String _mediaDescription(String value) => switch (value) {
  'audio' => 'Direct audio URL with background playback support.',
  'youtube' => 'A YouTube video ID opened in the in-app player.',
  'video' => 'Direct external video URL.',
  'pdf' => 'External PDF opened in a secure viewer.',
  'webpage' => 'Trusted external webpage.',
  _ => 'Externally hosted media.',
};

IconData _mediaIcon(String value) => switch (value) {
  'audio' => Icons.headphones_rounded,
  'youtube' || 'video' => Icons.play_circle_outline_rounded,
  'pdf' => Icons.picture_as_pdf_outlined,
  _ => Icons.open_in_new_rounded,
};
