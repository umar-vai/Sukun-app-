import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:uuid/uuid.dart';

class AdminContentEditorScreen extends ConsumerStatefulWidget {
  const AdminContentEditorScreen({
    super.key,
    this.contentItemId,
    this.initialKind,
  });

  final String? contentItemId;
  final AdminResourceKind? initialKind;

  @override
  ConsumerState<AdminContentEditorScreen> createState() =>
      _AdminContentEditorScreenState();
}

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

  /// Uses existing Super Admin RLS policies on public announcement images.
  Future<void> _uploadBlogImage({required bool cover}) async {
    if (_saving || _kind != AdminResourceKind.blog) return;
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (!mounted || selected == null) return;
    final bytes = await selected.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
      _show('PNG, JPG বা WebP ছবি সর্বোচ্চ ৩ MB হতে পারে।');
      return;
    }
    final ext = selected.extension?.toLowerCase();
    const mimeTypes = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
    };
    final mime = mimeTypes[ext];
    if (mime == null) return;
    setState(() => _saving = true);
    try {
      final storage = Supabase.instance.client.storage.from(
        'sukun-announcement-images',
      );
      final name = 'blogs/${const Uuid().v4()}.${ext == 'jpeg' ? 'jpg' : ext}';
      await storage.uploadBinary(
        name,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      if (!mounted) return;
      final url = storage.getPublicUrl(name);
      if (cover) {
        _controller('thumbnailUrl').text = url;
      } else {
        final editor = _controller('body');
        editor.text = '${editor.text.trimRight()}\n\n![ছবি]($url)\n';
      }
      setState(() {});
      _show(cover ? 'প্রচ্ছদ যুক্ত হয়েছে।' : 'লেখায় ছবি যুক্ত হয়েছে।');
    } catch (_) {
      if (mounted) _show('ছবি আপলোড হয়নি। Admin অনুমতি যাচাই করুন।');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// One step: whatever the admin saves is published (or stays published)
  /// right away. There is no draft, review or separate verification step.
  Future<void> _publish() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final input = _input();
    final error =
        _simpleValidationError() ??
        input.validate() ??
        input.publicationValidationError();
    if (error != null) {
      _show(error);
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(contentAdminRepositoryProvider);
      if (_initialStatus == 'archived' && _savedContentId != null) {
        // Archived resources cannot be edited until they are live again.
        await repository.transitionContent(
          contentItemId: _savedContentId!,
          transition: 'publish',
          requestId: const Uuid().v4(),
        );
        _initialStatus = 'published';
      }
      final item = await repository.saveContent(input);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(item);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.contentItemId == null
                ? 'উপকরণটি প্রকাশিত হয়েছে।'
                : 'পরিবর্তন প্রকাশিত হয়েছে।',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _show('উপকরণটি প্রকাশ করা যায়নি। আবার চেষ্টা করুন।');
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
      slug:
          _existingSlug ??
          (kind == AdminResourceKind.blog
              ? 'blog-${generatedResourceSlug(title, _resourceKey)}'
              : generatedResourceSlug(title, _resourceKey)),
      summary: _nullable('summary'),
      body:
          kind == AdminResourceKind.articleGuide ||
              kind == AdminResourceKind.blog
          ? _nullable('body')
          : null,
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
      status: 'published',
      requestId: const Uuid().v4(),
    );
  }

  String? _simpleValidationError() {
    final kind = _kind;
    if (kind == null) return 'আগে উপকরণের ধরন বেছে নিন।';
    if (kind == AdminResourceKind.duaAzkar) {
      final repeatCount = _nullable('repeatCount');
      if (repeatCount != null &&
          (int.tryParse(repeatCount) == null || int.parse(repeatCount) < 1)) {
        return 'তথ্যসূত্র অনুযায়ী ১ বা তার বেশি একটি সংখ্যা দিন।';
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
    return count == null ? null : 'অনুমোদিত তথ্যসূত্র অনুযায়ী কতবার: $count';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _savedContentId == null ? 'নতুন উপকরণ যোগ করুন' : 'উপকরণ সংশোধন করুন',
        ),
      ),
      // Save actions stay in reach while the long form scrolls.
      bottomNavigationBar: _kind == null
          ? null
          : SukunBottomActionBar(
              children: [
                FilledButton.icon(
                  key: const Key('content-editor-publish'),
                  onPressed: _saving ? null : _publish,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _savedContentId == null ? 'প্রকাশ করুন' : 'আপডেট করুন',
                  ),
                ),
              ],
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
              message:
                  'উপকরণটি সংরক্ষণাগারে রাখা বা সরিয়ে দেওয়া হয়ে থাকতে পারে।',
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
            eyebrow: _savedContentId == null ? 'নতুন উপকরণ' : 'সম্পাদনা',
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
                label: const Text('ধরন বদলান'),
              ),
            ),
          ],
          const SizedBox(height: 4),
          ..._fieldsFor(kind, data),
          _visibilityField(),
          const SizedBox(height: SukunSpace.lg),
        ],
      ),
    );
  }

  List<Widget> _fieldsFor(
    AdminResourceKind kind,
    _EditorData data,
  ) => switch (kind) {
    AdminResourceKind.quranAyah => [
      _field(
        'arabicText',
        'আরবি লেখা *',
        helper: 'আরবি লেখাটি হুবহু দিন।',
        lines: 7,
        required: true,
        rtl: true,
      ),
      _field(
        'banglaText',
        'বাংলা অনুবাদ *',
        helper: 'বাংলা অনুবাদ দিন।',
        lines: 6,
        required: true,
      ),
      _surahField(required: true),
      _ayahFields(required: true),
    ],
    AdminResourceKind.hadith => [
      _field(
        'arabicText',
        'আরবি লেখা *',
        helper: 'আরবি লেখাটি হুবহু দিন।',
        lines: 7,
        required: true,
        rtl: true,
      ),
      _field(
        'banglaText',
        'বাংলা অনুবাদ *',
        helper: 'বাংলা অনুবাদ দিন।',
        lines: 6,
        required: true,
      ),
      _field(
        'collectionName',
        'হাদিসের কিতাব *',
        helper: 'হাদিসগ্রন্থ ও কিতাবের নাম লিখুন।',
        required: true,
      ),
      _field(
        'hadithNumber',
        'হাদিস নম্বর *',
        helper: 'যেমন ১২৩৪।',
        required: true,
      ),
      _field(
        'grade',
        'হাদিসের মান (ঐচ্ছিক)',
        helper: 'যেমন সহিহ।',
      ),
    ],
    AdminResourceKind.quranAudio => [
      _titleField(),
      _surahField(required: true),
      _ayahFields(required: false),
      _field(
        'mediaUrl',
        'অডিও লিংক *',
        helper: 'https:// দিয়ে শুরু হওয়া অডিও লিংক দিন।',
        required: true,
        url: true,
      ),
      _field(
        'author',
        'কারীর নাম (ঐচ্ছিক)',
        helper: 'কারীর নাম বা প্রতিষ্ঠানের নাম জানা থাকলে লিখুন।',
      ),
    ],
    AdminResourceKind.ruqyahAudio => [
      _titleField(),
      _categoryField(data, prefix: 'ruqyah-', required: true),
      _field(
        'mediaUrl',
        'অডিও লিংক *',
        helper: 'https:// দিয়ে শুরু হওয়া অডিও লিংক দিন।',
        required: true,
        url: true,
      ),
    ],
    AdminResourceKind.bookPdf => [
      _titleField(),
      _field(
        'author',
        'লেখক (ঐচ্ছিক)',
        helper: 'প্রকাশনায় যে লেখকের নাম আছে, সেটি লিখুন।',
      ),
      _field(
        'mediaUrl',
        'পিডিএফ লিংক *',
        helper: 'https:// দিয়ে শুরু হওয়া পিডিএফ লিংক দিন।',
        required: true,
        url: true,
      ),
    ],
    AdminResourceKind.video => [
      _titleField(),
      _field(
        'mediaUrl',
        'ভিডিও লিংক *',
        helper: 'ইউটিউব বা অন্য ভিডিও লিংক দিন।',
        required: true,
        url: true,
      ),
    ],
    AdminResourceKind.duaAzkar => [
      _field(
        'arabicText',
        'আরবি *',
        helper: 'আরবি লেখাটি হুবহু দিন।',
        lines: 6,
        required: true,
        rtl: true,
      ),
      _field(
        'banglaText',
        'বাংলা *',
        helper: 'বাংলা অর্থ বা অনুবাদ দিন।',
        lines: 5,
        required: true,
      ),
      _categoryField(data, prefix: 'dua-azkar', required: true),
      _field(
        'repeatCount',
        'পাঠের সংখ্যা (ঐচ্ছিক)',
        helper: 'কতবার পড়তে হবে, জানা থাকলে দিন।',
        numeric: true,
      ),
    ],
    AdminResourceKind.blog => [
      _titleField(),
      _field(
        'body',
        'ব্লগের সম্পূর্ণ লেখা *',
        helper: '# শিরোনাম এবং ## উপশিরোনাম ব্যবহার করতে পারেন।',
        lines: 16,
        required: true,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _uploadBlogImage(cover: true),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('প্রচ্ছদের ছবি'),
          ),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _uploadBlogImage(cover: false),
            icon: const Icon(Icons.add_to_photos_outlined),
            label: const Text('লেখায় ছবি যোগ করুন'),
          ),
        ],
      ),
      if (_controller('thumbnailUrl').text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _controller('thumbnailUrl').text,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
    ],
    AdminResourceKind.articleGuide => [
      _titleField(),
      _field(
        'body',
        'সম্পূর্ণ লেখা *',
        helper: 'পাঠকের জন্য পুরো লেখাটি লিখুন।',
        lines: 12,
        required: true,
      ),
      _field(
        'author',
        'লেখক (ঐচ্ছিক)',
        helper: 'জানা থাকলে লেখকের নাম দিন।',
      ),
    ],
  };

  Widget _titleField() => _field(
    'title',
    'শিরোনাম *',
    helper: 'সংক্ষিপ্ত ও পরিষ্কার একটি নাম লিখুন।',
    required: true,
  );

  Widget _surahField({required bool required}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SukunChoiceField<String>(
      label: 'সূরা${required ? ' *' : ''}',
      placeholder: 'সূরা বেছে নিন',
      helperText: 'এই উপকরণটি কোন সূরার, তা বেছে নিন।',
      value: _nullable('surahNumber'),
      options: [
        for (var number = 1; number <= 114; number++)
          SukunChoiceOption(
            value: '$number',
            title: 'সূরা $number',
            description: 'কুরআনের $number নম্বর সূরা',
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
          required ? 'আয়াত নম্বর *' : 'শুরুর আয়াত (ঐচ্ছিক)',
          helper: required
              ? 'আয়াত নম্বর লিখুন, যেমন ২৫৫।'
              : 'অডিওতে নির্দিষ্ট আয়াত থাকলে নম্বর দিন।',
          required: required,
          numeric: true,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _field(
          'ayahEndNumber',
          'শেষ আয়াত (ঐচ্ছিক)',
          helper: 'একাধিক আয়াত হলে শেষ আয়াত নম্বর দিন।',
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
        placeholder: 'সবচেয়ে মানানসই বিভাগ বাছুন',
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

  Widget _visibilityField() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SukunChoiceField<String>(
      label: 'কারা দেখতে পারবেন?',
      placeholder: 'দর্শক বেছে নিন',
      value: _visibility,
      options: const [
        SukunChoiceOption(
          value: 'public',
          title: 'সবাই',
          icon: Icons.public_rounded,
        ),
        SukunChoiceOption(
          value: 'patient_only',
          title: 'লগইন করা রোগীরা',
          icon: Icons.person_outline_rounded,
        ),
        SukunChoiceOption(
          value: 'assigned_only',
          title: 'শুধু নির্ধারিত রোগীরা',
          icon: Icons.assignment_ind_outlined,
        ),
        SukunChoiceOption(
          value: 'staff_only',
          title: 'শুধু কর্মীরা',
          icon: Icons.admin_panel_settings_outlined,
        ),
      ],
      onChanged: (value) => setState(() => _visibility = value),
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
        Icon(Icons.chevron_right_rounded, color: SukunColors.deepTide),
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
  AdminResourceKind.quranAyah => "কুরআনের আয়াত",
  AdminResourceKind.hadith => 'হাদিস',
  AdminResourceKind.quranAudio => "কুরআন অডিও",
  AdminResourceKind.ruqyahAudio => 'রুকইয়াহ অডিও',
  AdminResourceKind.bookPdf => 'বই ও পিডিএফ',
  AdminResourceKind.video => 'ভিডিও',
  AdminResourceKind.duaAzkar => 'দোয়া ও যিকর',
  AdminResourceKind.articleGuide => 'আর্টিকেল',
  AdminResourceKind.blog => 'ব্লগ লিখুন',
};

String _kindCardDescription(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => 'আরবি আয়াত ও বাংলা অনুবাদ',
  AdminResourceKind.hadith => 'হাদিসের লেখা ও নম্বর',
  AdminResourceKind.quranAudio => 'সূরা বা আয়াতের অডিও লিংক',
  AdminResourceKind.ruqyahAudio => 'রুকইয়াহ অডিও লিংক',
  AdminResourceKind.bookPdf => 'বই বা পিডিএফের লিংক',
  AdminResourceKind.video => 'ইউটিউব বা ভিডিওর লিংক',
  AdminResourceKind.duaAzkar => 'দোয়া ও যিকর',
  AdminResourceKind.articleGuide => 'লেখা বা নির্দেশিকা',
  AdminResourceKind.blog => 'ছবি ও শিরোনামসহ ব্লগ',
};

String _kindInstruction(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => 'আয়াত, অনুবাদ ও সূরা-আয়াত নম্বর দিন।',
  AdminResourceKind.hadith => 'হাদিসের লেখা, কিতাব ও নম্বর দিন।',
  AdminResourceKind.quranAudio => 'শিরোনাম, সূরা ও অডিও লিংক দিন।',
  AdminResourceKind.ruqyahAudio => 'শিরোনাম, বিভাগ ও অডিও লিংক দিন।',
  AdminResourceKind.bookPdf => 'শিরোনাম ও পিডিএফ লিংক দিন।',
  AdminResourceKind.video => 'শিরোনাম ও ভিডিও লিংক দিন।',
  AdminResourceKind.duaAzkar => 'আরবি, বাংলা ও বিভাগ দিন।',
  AdminResourceKind.articleGuide => 'শিরোনাম ও লেখা দিন।',
  AdminResourceKind.blog => 'শিরোনাম, লেখা ও ছবি দিন।',
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
  AdminResourceKind.blog => Icons.edit_note_outlined,
};

String? _repeatCount(String? reference) {
  if (reference == null) return null;
  return RegExp(
    r'(?:Repeat count from approved source|অনুমোদিত তথ্যসূত্র অনুযায়ী কতবার|কতবার পড়বেন): (\d+)',
  )
      .firstMatch(reference)
      ?.group(1);
}
