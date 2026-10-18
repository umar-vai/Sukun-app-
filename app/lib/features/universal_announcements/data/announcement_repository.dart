import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/core/config/app_environment.dart';

/// Non-clinical public notice only. Never store or broadcast patient records.
class UniversalAnnouncement {
  const UniversalAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    this.imagePath,
    this.linkUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String body;
  final String status;
  final String? imagePath;
  final String? linkUrl;
  final DateTime? publishedAt;

  bool get isPublished => status == 'published';

  factory UniversalAnnouncement.fromJson(Map<String, dynamic> json) {
    return UniversalAnnouncement(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      status: json['status'] as String,
      imagePath: json['image_path'] as String?,
      linkUrl: json['link_url'] as String?,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}

class AnnouncementDraft {
  const AnnouncementDraft({
    required this.title,
    required this.body,
    this.id,
    this.imagePath,
    this.linkUrl,
    this.status = 'draft',
  });

  final String? id;
  final String title;
  final String body;
  final String? imagePath;
  final String? linkUrl;
  final String status;

  String? validate() {
    if (title.trim().isEmpty || title.trim().length > 120) {
      return 'শিরোনাম ১–১২০ অক্ষরের মধ্যে হতে হবে।';
    }
    if (body.trim().isEmpty || body.trim().length > 5000) {
      return 'নোটিশের লেখা ১–৫০০০ অক্ষরের মধ্যে হতে হবে।';
    }
    if (status != 'draft' && status != 'published' && status != 'archived') {
      return 'নোটিশের অবস্থা সঠিক নয়।';
    }
    if (linkUrl != null && linkUrl!.trim().isNotEmpty) {
      final link = Uri.tryParse(linkUrl!.trim());
      if (link == null || link.scheme != 'https' || link.host.isEmpty) {
        return 'শুধু নিরাপদ HTTPS লিংক ব্যবহার করুন।';
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'body': body.trim(),
    'status': status,
    'image_path': imagePath,
    'link_url': linkUrl?.trim().isEmpty == true ? null : linkUrl?.trim(),
  };
}

abstract interface class AnnouncementRepository {
  Future<List<UniversalAnnouncement>> published();
  Future<List<UniversalAnnouncement>> recentPublished();
  Future<UniversalAnnouncement?> get(String id);
  Future<List<UniversalAnnouncement>> adminList();
  Future<UniversalAnnouncement> save(AnnouncementDraft draft);
  Future<String> uploadImage({
    required String name,
    required List<int> bytes,
    required String mimeType,
  });
  String imageUrl(String path);
}

class SupabaseAnnouncementRepository implements AnnouncementRepository {
  const SupabaseAnnouncementRepository(this._client);
  final SupabaseClient? _client;

  SupabaseClient get client {
    final found = _client;
    if (found == null) throw StateError('App backend is not configured.');
    return found;
  }

  static const bucket = 'sukun-announcement-images';

  @override
  Future<List<UniversalAnnouncement>> published() async {
    if (_client == null) return [];
    const pageSize = 100;
    final notices = <UniversalAnnouncement>[];
    for (var offset = 0; ; offset += pageSize) {
      final page = await client
          .from('universal_announcements')
          .select()
          .eq('status', 'published')
          .order('published_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + pageSize - 1);
      notices.addAll(page.map(UniversalAnnouncement.fromJson));
      if (page.length < pageSize) break;
    }
    return notices;
  }

  /// Small bounded feed for app foreground polling; never fetch the whole
  /// history every minute. Published-only RLS still controls visibility.
  @override
  Future<List<UniversalAnnouncement>> recentPublished() async {
    if (_client == null) return [];
    final page = await client
        .from('universal_announcements')
        .select()
        .eq('status', 'published')
        .order('published_at', ascending: false)
        .order('id', ascending: false)
        .limit(25);
    return page.map(UniversalAnnouncement.fromJson).toList(growable: false);
  }

  @override
  Future<UniversalAnnouncement?> get(String id) async {
    if (_client == null) return null;
    final result = await client
        .from('universal_announcements')
        .select()
        .eq('id', id)
        .maybeSingle();
    return result == null ? null : UniversalAnnouncement.fromJson(result);
  }

  @override
  Future<List<UniversalAnnouncement>> adminList() async {
    final result = await client
        .from('universal_announcements')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return result.map(UniversalAnnouncement.fromJson).toList();
  }

  @override
  Future<UniversalAnnouncement> save(AnnouncementDraft draft) async {
    final problem = draft.validate();
    if (problem != null) throw FormatException(problem);
    final Map<String, dynamic> result;
    if (draft.id == null) {
      result = await client
          .from('universal_announcements')
          .insert(draft.toJson())
          .select()
          .single();
    } else {
      result = await client
          .from('universal_announcements')
          .update(draft.toJson())
          .eq('id', draft.id!)
          .select()
          .single();
    }
    return UniversalAnnouncement.fromJson(result);
  }

  @override
  Future<String> uploadImage({
    required String name,
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
      throw const FormatException('ছবি ৩ MB-এর মধ্যে হতে হবে।');
    }
    const mimeToExtension = {
      'image/png': 'png',
      'image/jpeg': 'jpg',
      'image/webp': 'webp',
    };
    final extension = mimeToExtension[mimeType];
    if (extension == null) {
      throw const FormatException('PNG, JPG অথবা WebP ছবি ব্যবহার করুন।');
    }
    final path =
        'notices/${DateTime.now().microsecondsSinceEpoch}-${name.hashCode.abs()}.$extension';
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    return path;
  }

  @override
  String imageUrl(String path) =>
      client.storage.from(bucket).getPublicUrl(path);
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return SupabaseAnnouncementRepository(
    AppEnvironment.isSupabaseConfigured ? Supabase.instance.client : null,
  );
});

final publishedAnnouncementsProvider =
    FutureProvider<List<UniversalAnnouncement>>((ref) async {
      return ref.read(announcementRepositoryProvider).published();
    });
