import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';

/// Uses verified Super Admin RLS. Hiding routes/buttons never grants privilege.
class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends ConsumerState<AdminAnnouncementsScreen> {
  late Future<List<UniversalAnnouncement>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = ref.read(announcementRepositoryProvider).adminList();
  }

  void _refresh() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: 'সবার জন্য নোটিশ',
    selectedIndex: 2,
    actions: [
      IconButton(
        tooltip: 'রিফ্রেশ',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push('/admin/announcements/new').then((_) {
        if (mounted) _refresh();
      }),
      icon: const Icon(Icons.add),
      label: const Text('নতুন নোটিশ'),
    ),
    body: FutureBuilder<List<UniversalAnnouncement>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text('নোটিশ লোড হয়নি — আবার চেষ্টা করুন'),
            ),
          );
        }
        final items = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'এখানে প্রকাশিত নোটিশ সব Guest, Member ও Patient দেখতে পাবেন। '
                  'এ পর্যায়ে ফোনে দূরবর্তী Push Delivery সক্রিয় নয়। '
                  'সেটির জন্য Firebase sender ও বাস্তব ফোনের পরীক্ষা প্রয়োজন।',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('কোনো নোটিশ তৈরি করা হয়নি।'),
              ),
            for (final notice in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    notice.isPublished
                        ? Icons.campaign_rounded
                        : Icons.edit_note_rounded,
                  ),
                  title: Text(notice.title),
                  subtitle: Text(
                    notice.status == 'published'
                        ? 'প্রকাশিত'
                        : notice.status == 'draft'
                            ? 'ড্রাফট'
                            : 'আর্কাইভ',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context
                      .push('/admin/announcements/' + notice.id + '/edit')
                      .then((_) {
                        if (mounted) _refresh();
                      }),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class AdminAnnouncementEditorScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementEditorScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<AdminAnnouncementEditorScreen> createState() =>
      _AdminAnnouncementEditorScreenState();
}

class _AdminAnnouncementEditorScreenState
    extends ConsumerState<AdminAnnouncementEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  String? _imagePath;
  PlatformFile? _imageFile;
  String _status = 'draft';
  bool _busy = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loading = true;
      _readExisting();
    }
  }

  Future<void> _readExisting() async {
    try {
      final notice = await ref.read(announcementRepositoryProvider).get(widget.id!);
      if (!mounted) return;
      if (notice == null) {
        setState(() => _error = 'নোটিশটি পাওয়া যায়নি।');
        return;
      }
      setState(() {
        _title.text = notice.title;
        _body.text = notice.body;
        _link.text = notice.linkUrl ?? '';
        _imagePath = notice.imagePath;
        _status = notice.status;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'নোটিশ লোড করা যায়নি।');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
      allowMultiple: false,
    );
    if (!mounted || result == null) return;
    final selected = result.files.single;
    if (selected.size > 3 * 1024 * 1024 || selected.bytes == null) {
      setState(() => _error = '৩ MB-এর কম PNG/JPG/WebP ছবি বেছে নিন।');
      return;
    }
    setState(() {
      _imageFile = selected;
      _error = null;
    });
  }

  Future<void> _save(String newStatus) async {
    if (_busy) return;
    final repo = ref.read(announcementRepositoryProvider);
    final draft = AnnouncementDraft(
      id: widget.id,
      title: _title.text,
      body: _body.text,
      imagePath: _imagePath,
      linkUrl: _link.text,
      status: newStatus,
    );
    final problem = draft.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var uploadedPath = _imagePath;
      if (_imageFile != null) {
        final extension = (_imageFile!.extension ?? '').toLowerCase();
        final mime = extension == 'png'
            ? 'image/png'
            : extension == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        uploadedPath = await repo.uploadImage(
          name: _imageFile!.name,
          bytes: _imageFile!.bytes!,
          mimeType: mime,
        );
      }
      await repo.save(
        AnnouncementDraft(
          id: widget.id,
          title: _title.text,
          body: _body.text,
          linkUrl: _link.text,
          imagePath: uploadedPath,
          status: newStatus,
        ),
      );
      ref.invalidate(publishedAnnouncementsProvider);
      if (!mounted) return;
      context.go('/admin/announcements');
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'নোটিশ সংরক্ষণ করা যায়নি। অনুমতি ও সংযোগ পরীক্ষা করুন।');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('নোটিশ তৈরি ও প্রকাশ')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                key: const Key('notice-title'),
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'শিরোনাম',
                  hintText: 'একটি সংক্ষিপ্ত গুরুত্বপূর্ণ ঘোষণা',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('notice-body'),
                controller: _body,
                minLines: 4,
                maxLines: 10,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'নোটিশের বিস্তারিত লেখা',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _chooseImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_imageFile == null
                    ? (_imagePath == null ? 'ছবি যোগ করুন' : 'ছবি পরিবর্তন করুন')
                    : _imageFile!.name),
              ),
              if (_imagePath != null || _imageFile != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _imageFile = null;
                            _imagePath = null;
                          }),
                  child: const Text('ছবি বাদ দিন'),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('notice-link'),
                controller: _link,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'লিংক (ঐচ্ছিক)',
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('notice-save-draft'),
                      onPressed: () => _save('draft'),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('ড্রাফট সংরক্ষণ'),
                    ),
                    FilledButton.icon(
                      key: const Key('notice-publish'),
                      onPressed: () => _save('published'),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('সবার জন্য প্রকাশ করুন'),
                    ),
                    if (widget.id != null)
                      TextButton(
                        onPressed: () => _save('archived'),
                        child: const Text('আর্কাইভ করুন'),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              const Text(
                'নিরাপত্তা: নোটিশে রোগীর ব্যক্তিগত তথ্য বা গোপন প্রেসক্রিপশন যোগ করবেন না।',
              ),
            ],
          ),
  );
}
