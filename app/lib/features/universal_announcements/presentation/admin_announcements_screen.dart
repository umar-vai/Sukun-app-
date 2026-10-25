import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';
import 'package:sukun_life/features/universal_announcements/presentation/universal_announcements_screen.dart';

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
    selectedIndex: 3,
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
                      .push('/admin/announcements/${notice.id}/edit')
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
  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _imageExtension;
  String _status = 'draft';
  DateTime? _countdownEndsAt;
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
      final notice = await ref
          .read(announcementRepositoryProvider)
          .get(widget.id!);
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
        _countdownEndsAt = notice.countdownEndsAt?.toLocal();
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'নোটিশ লোড করা যায়নি।');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCountdownEnd() async {
    final now = DateTime.now();
    final initial = _countdownEndsAt != null &&
            _countdownEndsAt!.isAfter(now) &&
            _countdownEndsAt!.isBefore(now.add(const Duration(days: 30)))
        ? _countdownEndsAt!
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    final selected = DateTime(
      date.year, date.month, date.day, time.hour, time.minute,
    );
    if (!selected.isAfter(now) ||
        selected.isAfter(now.add(const Duration(days: 30)))) {
      setState(() => _error = 'আগামী ৩০ দিনের মধ্যে সময় নির্বাচন করুন।');
      return;
    }
    setState(() {
      _countdownEndsAt = selected;
      _error = null;
    });
  }

  Future<void> _chooseImage() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (!mounted || selected == null) return;
    final bytes = await selected.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > 900 * 1024) {
      setState(() => _error = 'পুশ ছবির জন্য ৯০০ KB-এর মধ্যে ছবি দিন।');
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _imageFileName = selected.name;
      _imageExtension = selected.extension;
      _error = null;
    });
  }

  void _preview() {
    final draft = AnnouncementDraft(
      title: _title.text,
      body: _body.text,
      imagePath: _imagePath,
      countdownEndsAt: _countdownEndsAt,
      linkUrl: _link.text,
    );
    final problem = draft.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _error = null);
    final repository = ref.read(announcementRepositoryProvider);
    final ImageProvider? image = _imageBytes != null
        ? MemoryImage(_imageBytes!)
        : _imagePath != null
        ? NetworkImage(repository.imageUrl(_imagePath!))
        : null;
    final notice = UniversalAnnouncement(
      id: widget.id ?? '',
      title: draft.title.trim(),
      body: draft.body.trim(),
      status: 'draft',
      imagePath: draft.imagePath,
      countdownEndsAt: draft.countdownEndsAt,
      linkUrl: draft.linkUrl,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 510,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
          ),
          child: UniversalNoticePanel(
            notice: notice,
            image: image,
            isPreview: true,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  Future<void> _save(String newStatus) async {
    if (_busy) return;
    final repo = ref.read(announcementRepositoryProvider);
    final draft = AnnouncementDraft(
      id: widget.id,
      title: _title.text,
      body: _body.text,
      imagePath: _imagePath,
      countdownEndsAt: _countdownEndsAt,
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
      if (_imageBytes != null) {
        final extension = (_imageExtension ?? '').toLowerCase();
        final mime = extension == 'png'
            ? 'image/png'
            : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
        uploadedPath = await repo.uploadImage(
          name: _imageFileName!,
          bytes: _imageBytes!,
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
          countdownEndsAt: _countdownEndsAt,
          status: newStatus,
        ),
      );
      ref.invalidate(publishedAnnouncementsProvider);
      if (!mounted) return;
      context.go('/admin/announcements');
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'নোটিশ সংরক্ষণ করা যায়নি। অনুমতি ও সংযোগ পরীক্ষা করুন।',
        );
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
              if (widget.id != null) ...[
                Text('বর্তমান অবস্থা: $_status'),
                const SizedBox(height: 12),
              ],
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
                label: Text(
                  _imageBytes == null
                      ? (_imagePath == null
                            ? 'ছবি যোগ করুন'
                            : 'ছবি পরিবর্তন করুন')
                      : _imageFileName!,
                ),
              ),
              if (_imagePath != null || _imageBytes != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _imageBytes = null;
                          _imageFileName = null;
                          _imageExtension = null;
                          _imagePath = null;
                        }),
                  child: const Text('ছবি বাদ দিন'),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'কাউন্টডাউন (ঐচ্ছিক)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _countdownEndsAt == null
                            ? 'কোনো শেষ সময় দেওয়া হয়নি'
                            : 'শেষ: ${MaterialLocalizations.of(context).formatMediumDate(_countdownEndsAt!)} • ${TimeOfDay.fromDateTime(_countdownEndsAt!).format(context)}',
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('notice-set-countdown'),
                            onPressed: _busy ? null : _pickCountdownEnd,
                            icon: const Icon(Icons.timer_outlined),
                            label: const Text('শেষ সময় নির্ধারণ'),
                          ),
                          if (_countdownEndsAt != null)
                            TextButton(
                              key: const Key('notice-clear-countdown'),
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _countdownEndsAt = null,
                                    ),
                              child: const Text('কাউন্টডাউন বাদ দিন'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                      key: const Key('notice-preview'),
                      onPressed: _preview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('আগে দেখে নিন'),
                    ),
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
