import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:uuid/uuid.dart';

class AdminContentEditorScreen extends ConsumerStatefulWidget {
  const AdminContentEditorScreen({super.key, this.contentItemId, this.initialKind});

  final String? contentItemId;
  final AdminResourceKind? initialKind;

  @override
  ConsumerState<AdminContentEditorScreen> createState() =>
      _AdminContentEditorScreenState();
}

enum _SaveAction { draft, preview, submit }

class _AdminContentEditorScreenState
    extends ConsumerState<AdminContentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final String _resourceKey = const Uuid().v4();
  late Future<_EditorData> _data;
  AdminResourceKind? _kind;
  String _visibility = 'public';
  String? _categoryId;
  String? _savedContentId;
  String? _initialStatus;
  String? _existingSlug;
  String? _existingType;
  bool _populated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _savedContentId = widget.contentItemId;
    if (_savedContentId == null) _kind = widget.initialKind;
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
      if (_savedContentId != null) repository.getContent(_savedContentId!),
    ]);
    return _EditorData(
      categories: results[0] as List<ContentCategory>,
      allContent: results[1] as List<AdminContentItem>,
      item: _savedContentId == null ? null : results[2] as AdminContentItem?,
    );
  }

  void _populate(AdminContentItem? item, List<ContentCategory> categories) {
    if (_populated) return;
    _populated = true;
    if (item == null) {
      _categoryId = switch (_kind) {
        AdminResourceKind.ruqyahAudio =>
          _categoryIdForSlug(categories, 'ruqyah-audio'),
        AdminResourceKind.duaAzkar =>
          _categoryIdForSlug(categories, 'dua-azkar'),
        _ => null,
      };
      return;
    }
    ContentCategory? category;
    for (final candidate in categories) {
      if (candidate.id == item.categoryId) category = candidate;
    }
    _kind = resourceKindForItem(item, category: category);
    _visibility = item.visibility;
    _categoryId = item.categoryId;
    _initialStatus = item.status;
    _existingSlug = item.slug;
    _existingType = item.type;
    final values = <String, Object?>{
      'title': item.title,
      'titleBn': item.titleBn,
      'summary': item.summary,
      'body': item.body,
      'arabicText': item.arabicText,
      'banglaText': item.banglaText,
      'sourceType': item.sourceType,
      'sourceReference': item.sourceReference,
      'sourceUrl': item.sourceUrl,
      'sourceEdition': item.sourceEdition,
      'translationSource': item.translationSource,
      'surahNumber': item.surahNumber,
      'ayahNumber': item.ayahNumber,
      'ayahEndNumber': item.ayahEndNumber,
      'collectionName': item.collectionName,
      'hadithNumber': item.hadithNumber,
      'grade': item.grade,
      'author': item.author,
      'rightsNote': item.rightsNote,
      'mediaUrl': item.mediaSourceType == 'youtube'
          ? item.sourceUrl ??
                (item.youtubeVideoId == null
                    ? null
                    : 'https://www.youtube.com/watch?v=${item.youtubeVideoId}')
          : item.mediaUrl,
      'thumbnailUrl': item.thumbnailUrl,
      'repeatCount': _repeatCount(item.referenceText),
    };
    for (final entry in values.entries) {
      _controller(entry.key).text = entry.value?.toString() ?? '';
    }
  }

  Future<void> _save(_SaveAction action) async {
    if (!_formKey.currentState!.validate()) return;
    final input = _input();
    final error = input.validate() ?? _simpleValidationError();
    if (error != null) {
      _show(error);
      return;
    }
    if (action == _SaveAction.submit) {
      final publicationError = input.publicationValidationError();
      if (publicationError != null && _kind?.isCanonical == true) {
        _show(publicationError);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(contentAdminRepositoryProvider);
      if (_initialStatus == 'published' && _savedContentId != null) {
        await repository.transitionContent(
          contentItemId: _savedContentId!,
          transition: 'unpublish',
          requestId: const Uuid().v4(),
        );
        _initialStatus = _kind?.isCanonical == true ? 'verified' : 'review';
      }
      var item = await repository.saveContent(input);
      _savedContentId = item.id;
      _existingSlug = item.slug;
      _existingType = item.type;
      _initialStatus = item.status;
      if (action == _SaveAction.submit) {
        item = await repository.transitionContent(
          contentItemId: item.id,
          transition: 'submit',
          requestId: const Uuid().v4(),
        );
        _initialStatus = item.status;
      }
      if (!mounted) return;
      if (action == _SaveAction.preview) {
        await context.push('/admin/content/${item.id}/preview');
        if (mounted) {
          setState(() => _data = _load());
        }
      } else {
        Navigator.of(context).pop(item);
      }
    } catch (error) {
      if (mounted) _show('উপকরণটি সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  SaveContentInput _input() {
    final kind = _kind!;
    final title = _generatedTitle(kind);
    final mediaLink = _nullable('mediaUrl');
    final youtubeId = kind == AdminResourceKind.video && mediaLink != null
        ? inferYoutubeVideoId(mediaLink)
        : '';
    final type = _existingType ?? kind.contentType;
    final mediaSourceType = kind == AdminResourceKind.video
        ? (youtubeId.isNotEmpty ? 'youtube' : 'direct_video_url')
        : kind.mediaSourceType;
    final referenceText = kind == AdminResourceKind.duaAzkar
        ? _repeatReference()
        : null;
    return SaveContentInput(
      contentItemId: _savedContentId,
      type: type,
      categoryId: _categoryId,
      title: title,
      titleBn: kind == AdminResourceKind.duaAzkar
          ? _nullable('banglaText')
          : _nullable('titleBn'),
      slug: _existingSlug ?? generatedResourceSlug(title, _resourceKey),
      summary: _nullable('summary'),
      body: kind == AdminResourceKind.articleGuide ? _nullable('body') : null,
      arabicText: _nullable('arabicText'),
      banglaText: _nullable('banglaText'),
      referenceText: referenceText,
      sourceType: _nullable('sourceType'),
      sourceReference: _nullable('sourceReference'),
      sourceUrl: kind == AdminResourceKind.video && youtubeId.isNotEmpty
          ? mediaLink
          : _nullable('sourceUrl'),
      sourceEdition: _nullable('sourceEdition'),
      translationSource: _nullable('translationSource'),
      surahNumber: _integer('surahNumber'),
      ayahNumber: _integer('ayahNumber'),
      ayahEndNumber: _integer('ayahEndNumber'),
      collectionName: _nullable('collectionName'),
      bookName: kind == AdminResourceKind.hadith
          ? _nullable('collectionName')
          : null,
      hadithNumber: _nullable('hadithNumber'),
      grade: _nullable('grade'),
      author: _nullable('author'),
      rightsNote: _nullable('rightsNote'),
      thumbnailUrl: _nullable('thumbnailUrl'),
      mediaSourceType: mediaSourceType,
      mediaUrl: youtubeId.isEmpty ? mediaLink : null,
      youtubeVideoId: youtubeId.isEmpty ? null : youtubeId,
      visibility: _visibility,
      status: 'draft',
      requestId: const Uuid().v4(),
    );
  }

  String? _simpleValidationError() {
    final kind = _kind;
    if (kind == null) return 'আগে উপকরণের ধরন বেছে নিন।';
    if (kind.requiresApprovedSource && _nullable('sourceType') == null) {
      return 'অনুমোদিত উৎসটি বেছে নিন।';
    }
    if (kind.requiresApprovedSource &&
        (_nullable('sourceReference') == null ||
            _nullable('sourceEdition') == null)) {
      return 'উৎসের নাম ও সংস্করণের তথ্য দিন।';
    }
    if (kind == AdminResourceKind.duaAzkar) {
      final repeatCount = _nullable('repeatCount');
      if (repeatCount != null &&
          (int.tryParse(repeatCount) == null || int.parse(repeatCount) < 1)) {
        return 'উৎস অনুযায়ী ১ বা তার বেশি একটি সংখ্যা দিন।';
      }
    }
    return null;
  }

  String _generatedTitle(AdminResourceKind kind) => switch (kind) {
    AdminResourceKind.quranAyah =>
      'Surah ${_text('surahNumber')}, Ayah ${_ayahLabel()}',
    AdminResourceKind.hadith =>
      '${_text('collectionName')} — Hadith ${_text('hadithNumber')}',
    AdminResourceKind.duaAzkar => _shortTitle(
      _nullable('banglaText') ?? _nullable('arabicText') ?? 'Dua / Azkar',
    ),
    _ => _text('title'),
  };

  String _ayahLabel() {
    final start = _text('ayahNumber');
    final end = _nullable('ayahEndNumber');
    return end == null ? start : '$start–$end';
  }

  String? _repeatReference() {
    final count = _nullable('repeatCount');
    return count == null ? null : 'Repeat count from approved source: $count';
  }

  String _shortTitle(String value) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= 56
        ? singleLine
        : '${singleLine.substring(0, 53)}…';
  }

  String _text(String key) => _controller(key).text.trim();
  String? _nullable(String key) {
    final value = _text(key);
    return value.isEmpty ? null : value;
  }

  int? _integer(String key) => int.tryParse(_text(key));

  void _show(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  void _chooseKind(AdminResourceKind kind, List<ContentCategory> categories) {
    setState(() {
      _kind = kind;
      _existingType = null;
      _categoryId = switch (kind) {
        AdminResourceKind.ruqyahAudio => _categoryIdForSlug(
          categories,
          'ruqyah-audio',
        ),
        AdminResourceKind.duaAzkar => _categoryIdForSlug(
          categories,
          'dua-azkar',
        ),
        _ => null,
      };
    });
  }

  String? _categoryIdForSlug(List<ContentCategory> categories, String slug) {
    for (final category in categories) {
      if (category.slug == slug) return category.id;
    }
    return null;
  }

  Future<void> _editApprovedSource() async {
    final sourceType = ValueNotifier<String>(
      _nullable('sourceType') ?? 'official_dataset',
    );
    final reference = TextEditingController(
      text: _controller('sourceReference').text,
    );
    final edition = TextEditingController(
      text: _controller('sourceEdition').text,
    );
    final translation = TextEditingController(
      text: _controller('translationSource').text,
    );
    final sourceUrl = TextEditingController(
      text: _controller('sourceUrl').text,
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SukunPageIntro(
                eyebrow: 'উৎস যাচাই',
                title: 'অনুমোদিত উৎস',
                subtitle: 'লেখাটি কোথা থেকে নেওয়া, তা লিখুন যাতে যাচাই করা যায়।',
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: sourceType,
                builder: (context, value, _) => SukunChoiceField<String>(
                  label: 'উৎসের ধরন',
                  placeholder: 'উৎসের ধরন বেছে নিন',
                  value: value,
                  options: const [
                    SukunChoiceOption(
                      value: 'official_dataset',
                      title: 'সরকারি বা যাচাই করা ডিজিটাল উৎস',
                      description:
                          'A trusted API or checked digital text source.',
                      icon: Icons.dataset_outlined,
                    ),
                    SukunChoiceOption(
                      value: 'licensed_publication',
                      title: 'অনুমতি-প্রাপ্ত প্রকাশনা',
                      description:
                          'A printed or digital edition Sukun Life may use.',
                      icon: Icons.menu_book_outlined,
                    ),
                    SukunChoiceOption(
                      value: 'sukun_approved_reference',
                      title: 'সুকুন লাইফ অনুমোদিত উৎস',
                      description:
                          'A source already checked by the Sukun Life team.',
                      icon: Icons.verified_outlined,
                    ),
                  ],
                  onChanged: (next) => sourceType.value = next,
                ),
              ),
              const SizedBox(height: 12),
              _SourceTextField(
                controller: reference,
                label: 'উৎসের নাম বা তথ্যসূত্র *',
                helper: 'Example: publication title, collection reference, or dataset name.',
              ),
              _SourceTextField(
                controller: edition,
                label: 'প্রকাশনা বা সংস্করণ *',
                helper: 'Enter the edition, revision, or dataset version shown by the source.',
              ),
              if (_nullable('banglaText') != null)
                _SourceTextField(
                  controller: translation,
                  label: 'বাংলা অনুবাদের উৎস *',
                  helper: 'Name the approved Bangla translator or publication.',
                ),
              _SourceTextField(
                controller: sourceUrl,
                label: 'উৎসের লিংক (ঐচ্ছিক)',
                helper: 'Paste an HTTPS link when the source is online.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (reference.text.trim().isEmpty ||
                        edition.text.trim().isEmpty ||
                        (_nullable('banglaText') != null &&
                            translation.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Complete the required source information.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(sheetContext, true);
                  },
                  child: const Text('এই উৎস ব্যবহার করুন'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) {
      _controller('sourceType').text = sourceType.value;
      _controller('sourceReference').text = reference.text.trim();
      _controller('sourceEdition').text = edition.text.trim();
      _controller('translationSource').text = translation.text.trim();
      _controller('sourceUrl').text = sourceUrl.text.trim();
      if (mounted) setState(() {});
    }
    sourceType.dispose();
    reference.dispose();
    edition.dispose();
    translation.dispose();
    sourceUrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _savedContentId == null ? 'নতুন উপকরণ যোগ করুন' : 'উপকরণ সংশোধন করুন',
        ),
      ),
      body: FutureBuilder<_EditorData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'ফর্ম তৈরি হচ্ছে…');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: () => setState(() => _data = _load()),
            );
          }
          final data = snapshot.data!;
          _populate(data.item, data.categories);
          if (_savedContentId != null && data.item == null) {
            return const AppEmptyState(
              title: 'উপকরণটি পাওয়া যায়নি',
              message: 'উপকরণটি সংরক্ষণাগারে রাখা বা সরিয়ে দেওয়া হয়ে থাকতে পারে।',
              icon: Icons.search_off_rounded,
            );
          }
          if (_kind == null) return _typeChooser(data: data);
          return _resourceForm(data);
        },
      ),
    );
  }

  Widget _typeChooser({required _EditorData data}) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
    children: [
      const SukunPageIntro(
        eyebrow: 'প্রথম ধাপ',
        title: 'কোন উপকরণ যোগ করবেন?',
        subtitle: 'উপকরণের ধরন বেছে নিন। পরের ধাপে শুধু প্রয়োজনীয় তথ্য চাইবে।',
        trailing: SukunIconBadge(icon: Icons.add_box_outlined, size: 54),
      ),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 520;
          final width = twoColumns
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final kind in AdminResourceKind.values)
                SizedBox(
                  width: width,
                  child: _ResourceTypeCard(
                    kind: kind,
                    onTap: () => _chooseKind(kind, data.categories),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _resourceForm(_EditorData data) {
    final kind = _kind!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          SukunPageIntro(
            eyebrow: 'উপকরণের তথ্য দিন',
            title: _kindTitle(kind),
            subtitle: _kindInstruction(kind),
            trailing: SukunIconBadge(icon: _kindIcon(kind), size: 54),
          ),
          if (_savedContentId == null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _kind = null),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('অন্য বিভাগ বেছে নিন'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (kind.isCanonical)
            const SukunSurface(
              tone: SukunSurfaceTone.warning,
              showBorder: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'অনুমোদিত উৎস থেকে লেখাটি হুবহু দিন। প্রকাশের আগে যাচাই করা হবে।',
                    ),
                  ),
                ],
              ),
            ),
          ..._fieldsFor(kind, data),
          const SizedBox(height: 18),
          _advancedSettings(data),
          const SizedBox(height: 26),
          if (_saving) const LinearProgressIndicator(),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(_SaveAction.preview),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('আগে দেখে নিন'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _save(_SaveAction.draft),
                  child: const Text('খসড়া সংরক্ষণ করুন'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(_SaveAction.submit),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('যাচাইয়ের জন্য পাঠান'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _fieldsFor(
    AdminResourceKind kind,
    _EditorData data,
  ) => switch (kind) {
    AdminResourceKind.quranAyah => [
      _section('আয়াতের লেখা'),
      _field(
        'arabicText',
        'আরবি লেখা *',
        helper: 'Copy the Arabic exactly from the approved source.',
        lines: 7,
        required: true,
        rtl: true,
      ),
      _field(
        'banglaText',
        'বাংলা অনুবাদ *',
        helper: 'Copy the approved Bangla translation without rewriting it.',
        lines: 6,
        required: true,
      ),
      _surahField(required: true),
      _ayahFields(required: true),
      _approvedSourceField(),
    ],
    AdminResourceKind.hadith => [
      _section('হাদিসের লেখা'),
      _field(
        'arabicText',
        'আরবি লেখা *',
        helper: 'Copy the Arabic exactly as it appears in the approved source.',
        lines: 7,
        required: true,
        rtl: true,
      ),
      _field(
        'banglaText',
        'বাংলা অনুবাদ *',
        helper: 'Copy the approved Bangla translation without rewriting it.',
        lines: 6,
        required: true,
      ),
      _field(
        'collectionName',
        'হাদিসের কিতাব *',
        helper: 'Enter the collection and book name used by the source.',
        required: true,
      ),
      _field(
        'hadithNumber',
        'হাদিস নম্বর *',
        helper: 'Enter the number exactly as shown by the source.',
        required: true,
      ),
      _approvedSourceField(),
      _field(
        'grade',
        'হাদিসের মান (ঐচ্ছিক)',
        helper: 'Only enter a grade when the approved source provides one.',
      ),
    ],
    AdminResourceKind.quranAudio => [
      _section('অডিওর তথ্য'),
      _titleField(),
      _surahField(required: true),
      _ayahFields(required: false),
      _field(
        'mediaUrl',
        'অডিও লিংক *',
        helper: 'Paste the direct online audio link. The file will not be uploaded to Sukun Life.',
        required: true,
        url: true,
      ),
      _field(
        'author',
        'কারীর নাম বা উৎস (ঐচ্ছিক)',
        helper: 'Enter the reciter or organization when known.',
      ),
      _rightsField(),
    ],
    AdminResourceKind.ruqyahAudio => [
      _section('রুকইয়াহ অডিও'),
      _titleField(),
      _categoryField(data, prefix: 'ruqyah-', required: true),
      _field(
        'mediaUrl',
        'অডিও লিংক *',
        helper: 'Paste the direct online audio link. The file will not be uploaded to Sukun Life.',
        required: true,
        url: true,
      ),
      _rightsField(),
    ],
    AdminResourceKind.bookPdf => [
      _section('বই বা পিডিএফ'),
      _titleField(),
      _field(
        'author',
        'লেখক (ঐচ্ছিক)',
        helper: 'Enter the author exactly as credited by the publication.',
      ),
      _field(
        'mediaUrl',
        'পিডিএফ লিংক *',
        helper: 'Paste the external PDF link. The file will not be uploaded to Sukun Life.',
        required: true,
        url: true,
      ),
      _rightsField(),
    ],
    AdminResourceKind.video => [
      _section('ভিডিওর তথ্য'),
      _titleField(),
      _field(
        'mediaUrl',
        'ভিডিও লিংক *',
        helper: 'Paste the YouTube or direct video link. The video remains externally hosted.',
        required: true,
        url: true,
      ),
      _rightsField(),
    ],
    AdminResourceKind.duaAzkar => [
      _section('দোয়া বা যিকর'),
      _field(
        'arabicText',
        'আরবি *',
        helper: 'Copy the Arabic exactly from the approved source.',
        lines: 6,
        required: true,
        rtl: true,
      ),
      _field(
        'banglaText',
        'বাংলা *',
        helper: 'Enter the approved Bangla meaning or translation.',
        lines: 5,
        required: true,
      ),
      _categoryField(data, prefix: 'dua-azkar', required: true),
      _approvedSourceField(),
      _field(
        'repeatCount',
        'পাঠের সংখ্যা (ঐচ্ছিক)',
        helper:
            'Only enter a count when the approved source explicitly states it.',
        numeric: true,
      ),
    ],
    AdminResourceKind.articleGuide => [
      _section('লেখা বা নির্দেশিকা'),
      _titleField(),
      _field(
        'body',
        'সম্পূর্ণ লেখা *',
        helper: 'Write the complete reader-facing article or guide.',
        lines: 12,
        required: true,
      ),
      _field(
        'author',
        'লেখক বা উৎস (ঐচ্ছিক)',
        helper: 'Credit the author or source when applicable.',
      ),
    ],
  };

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 2),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _titleField() => _field(
    'title',
    'শিরোনাম *',
    helper: 'Use a short, clear title that readers will understand.',
    required: true,
  );

  Widget _rightsField() => _field(
    'rightsNote',
    'উৎস ও ব্যবহারের অনুমতি *',
    helper: 'State who owns the resource or why Sukun Life is allowed to link to it.',
    lines: 3,
    required: true,
  );

  Widget _surahField({required bool required}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SukunChoiceField<String>(
      label: 'সূরা${required ? ' *' : ''}',
      placeholder: 'Choose the Surah',
      helperText: 'এই উপকরণটি কোন সূরার, তা বেছে নিন।',
      value: _nullable('surahNumber'),
      options: [
        for (var number = 1; number <= 114; number++)
          SukunChoiceOption(
            value: '$number',
            title: 'Surah $number',
            description: 'Qur’an Surah number $number',
          ),
      ],
      onChanged: (value) =>
          setState(() => _controller('surahNumber').text = value),
    ),
  );

  Widget _ayahFields({required bool required}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _field(
          'ayahNumber',
          required ? 'Ayah number *' : 'Start Ayah (optional)',
          helper: required
              ? 'Enter the Ayah number, e.g. 255.'
              : 'Use this only when the audio covers selected Ayat.',
          required: required,
          numeric: true,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _field(
          'ayahEndNumber',
          'End Ayah (optional)',
          helper: 'For a range, enter the final Ayah number.',
          numeric: true,
        ),
      ),
    ],
  );

  Widget _categoryField(
    _EditorData data, {
    required String prefix,
    required bool required,
  }) {
    final options = data.categories
        .where(
          (category) => category.isActive && category.slug.startsWith(prefix),
        )
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SukunChoiceField<String>(
        label: 'বিভাগ${required ? ' *' : ''}',
        placeholder: 'Choose the most suitable category',
        helperText: 'এতে পাঠক সহজে উপকরণটি খুঁজে পাবেন।',
        value: _categoryId,
        options: [
          for (final category in options)
            SukunChoiceOption(
              value: category.id,
              title: category.name,
              description: category.nameBn,
            ),
        ],
        onChanged: (value) => setState(() => _categoryId = value),
      ),
    );
  }

  Widget _approvedSourceField() {
    final selected = _nullable('sourceReference');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SukunSurface(
        tone: selected == null
            ? SukunSurfaceTone.warning
            : SukunSurfaceTone.soft,
        radius: 18,
        onTap: _editApprovedSource,
        child: Row(
          children: [
            SukunIconBadge(
              icon: selected == null
                  ? Icons.add_moderator_outlined
                  : Icons.verified_outlined,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approved source *',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected ?? 'Tap to choose and record the checked source.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SukunColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _advancedSettings(_EditorData data) => SukunSurface(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.tune_rounded, color: SukunColors.deepTide),
      title: const Text('অতিরিক্ত সেটিংস'),
      subtitle: const Text('কে দেখতে পারবেন এবং অন্যান্য তথ্য'),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        SukunChoiceField<String>(
          label: 'কারা দেখতে পারবেন?',
          placeholder: 'দর্শক বেছে নিন',
          value: _visibility,
          options: const [
            SukunChoiceOption(
              value: 'public',
              title: 'সবাই',
              description: 'Guests and signed-in users can see it.',
              icon: Icons.public_rounded,
            ),
            SukunChoiceOption(
              value: 'patient_only',
              title: 'লগইন করা রোগীরা',
              description: 'Only authenticated Sukun Life patients can see it.',
              icon: Icons.person_outline_rounded,
            ),
            SukunChoiceOption(
              value: 'assigned_only',
              title: 'শুধু নির্ধারিত রোগীরা',
              description: 'Only patients with this resource in a care plan.',
              icon: Icons.assignment_ind_outlined,
            ),
            SukunChoiceOption(
              value: 'staff_only',
              title: 'শুধু সুকুন লাইফের কর্মীরা',
              description: 'Keep this resource inside the admin workspace.',
              icon: Icons.admin_panel_settings_outlined,
            ),
          ],
          onChanged: (value) => setState(() => _visibility = value),
        ),
        _field(
          'summary',
          'সংক্ষিপ্ত বিবরণ (ঐচ্ছিক)',
          helper: 'Add one or two sentences to help readers understand it.',
          lines: 3,
        ),
        _field(
          'thumbnailUrl',
          'প্রচ্ছদের ছবির লিংক (ঐচ্ছিক)',
          helper: 'Paste an HTTPS image link if a cover is available.',
          url: true,
        ),
      ],
    ),
  );

  Widget _field(
    String key,
    String label, {
    required String helper,
    int lines = 1,
    bool required = false,
    bool numeric = false,
    bool url = false,
    bool rtl = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: _controller(key),
      maxLines: lines,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      keyboardType: numeric
          ? TextInputType.number
          : url
          ? TextInputType.url
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'এই তথ্যটি লিখুন।';
        if (url && text.isNotEmpty && !text.startsWith('https://')) {
          return 'নিরাপদ HTTPS লিংক দিন।';
        }
        return null;
      },
    ),
  );
}

class _ResourceTypeCard extends StatelessWidget {
  const _ResourceTypeCard({required this.kind, required this.onTap});

  final AdminResourceKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SukunSurface(
    radius: 22,
    onTap: onTap,
    child: Row(
      children: [
        SukunIconBadge(icon: _kindIcon(kind), size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _kindTitle(kind),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _kindCardDescription(kind),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: SukunColors.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: SukunColors.deepTide),
      ],
    ),
  );
}

class _SourceTextField extends StatelessWidget {
  const _SourceTextField({
    required this.controller,
    required this.label,
    required this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String helper;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
      ),
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

String _kindTitle(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => "Qur'an Ayah",
  AdminResourceKind.hadith => 'Hadith',
  AdminResourceKind.quranAudio => "Qur'an / Surah Audio",
  AdminResourceKind.ruqyahAudio => 'Ruqyah Audio',
  AdminResourceKind.bookPdf => 'Book / PDF',
  AdminResourceKind.video => 'Video',
  AdminResourceKind.duaAzkar => 'Dua / Azkar',
  AdminResourceKind.articleGuide => 'Article / Guide',
};

String _kindCardDescription(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => 'Arabic Ayah and approved Bangla translation',
  AdminResourceKind.hadith => 'Sourced Hadith text and reference',
  AdminResourceKind.quranAudio => 'External Surah or selected-Ayah recitation',
  AdminResourceKind.ruqyahAudio => 'External approved Ruqyah recording',
  AdminResourceKind.bookPdf => 'Externally hosted book or PDF',
  AdminResourceKind.video => 'YouTube or direct external video',
  AdminResourceKind.duaAzkar => 'Approved Dua or daily Azkar',
  AdminResourceKind.articleGuide => 'Reader-friendly article or guide',
};

String _kindInstruction(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah =>
    'Enter the Ayah exactly as it appears in an approved source.',
  AdminResourceKind.hadith =>
    'Record the text and reference exactly from an approved collection.',
  AdminResourceKind.quranAudio =>
    'Link to an externally hosted recitation. No file will be uploaded.',
  AdminResourceKind.ruqyahAudio =>
    'Add an approved external recording and choose its Ruqyah category.',
  AdminResourceKind.bookPdf =>
    'Link to an externally hosted PDF and confirm permission to use it.',
  AdminResourceKind.video =>
    'Add a YouTube or direct video link without uploading the file.',
  AdminResourceKind.duaAzkar =>
    'Enter only sourced wording and repetition guidance.',
  AdminResourceKind.articleGuide =>
    'Write a clear reader-facing article with attribution where needed.',
};

IconData _kindIcon(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => Icons.auto_stories_outlined,
  AdminResourceKind.hadith => Icons.format_quote_rounded,
  AdminResourceKind.quranAudio => Icons.graphic_eq_rounded,
  AdminResourceKind.ruqyahAudio => Icons.headphones_rounded,
  AdminResourceKind.bookPdf => Icons.picture_as_pdf_outlined,
  AdminResourceKind.video => Icons.play_circle_outline_rounded,
  AdminResourceKind.duaAzkar => Icons.auto_awesome_rounded,
  AdminResourceKind.articleGuide => Icons.article_outlined,
};

String? _repeatCount(String? reference) {
  if (reference == null) return null;
  return RegExp(r'Repeat count from approved source: (\d+)')
      .firstMatch(reference)
      ?.group(1);
}
