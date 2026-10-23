import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

import 'approved_web_audio_request.dart';
import 'offline_byte_factory.dart';
import 'offline_byte_store.dart';

final offlineLibraryProvider = Provider<OfflineLibrary>((ref) {
  final library = OfflineLibrary();
  ref.onDispose(library.dispose);
  return library;
});

@immutable
class OfflineItem {
  const OfflineItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.size,
    required this.digest,
    required this.savedAt,
  });

  final String id;
  final String title;
  final String kind;
  final int size;
  final String digest;
  final DateTime savedAt;

  factory OfflineItem.fromJson(Map<String, dynamic> json) => OfflineItem(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: json['kind'] as String,
    size: json['size'] as int,
    digest: json['sha256'] as String,
    savedAt: DateTime.parse(json['saved'] as String),
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'size': size,
    'sha256': digest,
    'saved': savedAt.toIso8601String(),
  };
}

/// Offline entitlement is deliberately independent of content visibility.
/// Authorization to *stream* private patient media never grants permission to
/// copy it to an unencrypted public offline store.
bool canSaveOffline(
  ContentResource content, {
  required Set<String> ownerAuthorizedAudioUrls,
}) {
  if (content.status != 'published' || content.visibility != 'public') {
    return false;
  }
  final media = resolveResourceMedia(content.linkedResource);
  if (media?.uri == null ||
      !(media!.kind == ResourceMediaKind.audio ||
          media.kind == ResourceMediaKind.pdf)) {
    return false;
  }
  final uri = media.uri!;
  // Never cache expiring signatures or remote query tokens in public metadata.
  if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return false;
  // A negated note such as `not_offline_allowed` must never grant rights.
  final explicitRight = RegExp(r'(^|[\s,;])offline_allowed($|[\s,;])')
      .hasMatch((content.rightsNote ?? '').toLowerCase());
  if (media.kind == ResourceMediaKind.audio) {
    if (!uri.path.toLowerCase().endsWith('.mp3')) return false;
    // 19 owner-attested recordings are matched by exact reviewed source URL.
    return ownerAuthorizedAudioUrls.contains(uri.toString()) || explicitRight;
  }
  return uri.path.toLowerCase().endsWith('.pdf') && explicitRight;
}

Future<Set<String>> ownerAuthorizedAudioUrls() async {
  final source = await rootBundle.loadString(
    'assets/data/ruqyahbd_book_audio_crosswalk.json',
  );
  final catalog = jsonDecode(source) as Map<String, dynamic>;
  return (catalog['entries'] as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .where(
        (entry) =>
            entry['licensing'] ==
            'owner_attested_for_sukun_life_app_2026_10_12',
      )
      .map((entry) => entry['media_url'] as String)
      .toSet();
}

class OfflineLibrary extends ChangeNotifier {
  OfflineLibrary({
    OfflineByteStore? bytes,
    Future<SharedPreferences>? preferences,
    http.Client Function()? clientFactory,
    Future<Set<String>> Function()? authorizedAudioUrls,
    this.useWebMediaGateway = true,
  }) : _bytes = bytes ?? createOfflineByteStore(),
       _prefs = preferences ?? SharedPreferences.getInstance(),
       _clientFactory = clientFactory ?? http.Client.new,
       _authorizedAudioUrls = authorizedAudioUrls ?? ownerAuthorizedAudioUrls;

  // Saved media belongs to the user's local device/browser, not Supabase.
  // Do not impose an artificial cumulative cap: the OS/browser enforces its
  // real storage quota, and users can delete downloads from their library.
  // Retain the per-transfer limit until streaming writes and memory usage are
  // validated for bigger files. Server-side egress budgets remain independent.
  static const maxFileBytes = 100 * 1024 * 1024;

  /// Explicitly false only in synthetic/offline integration tests.
  final bool useWebMediaGateway;
  final OfflineByteStore _bytes;
  final Future<SharedPreferences> _prefs;
  final http.Client Function() _clientFactory;
  final Future<Set<String>> Function() _authorizedAudioUrls;
  String? _owner;
  int _revision = 0;
  List<OfflineItem> _items = const [];
  bool _busy = false;
  bool _cancel = false;
  double? _progress;
  String? _activeTitle;

  List<OfflineItem> get items => List.unmodifiable(_items);
  bool get busy => _busy;
  double? get progress => _progress;
  String? get activeTitle => _activeTitle;
  bool get ready => _owner != null;
  int get totalBytes => _items.fold<int>(0, (total, item) => total + item.size);

  String _key(String owner) =>
      'sukun.offline.public.v1.${Uri.encodeComponent(owner)}';
  String _byteKey(String owner, String resourceId) => '$owner:$resourceId';

  Future<void> open(String owner) async {
    if (_owner == owner) return;
    cancel();
    final revision = ++_revision;
    _owner = null;
    _items = const [];
    notifyListeners();
    final prefs = await _prefs;
    final raw = prefs.getString(_key(owner));
    final loaded = <OfflineItem>[];
    if (raw != null) {
      try {
        for (final value in jsonDecode(raw) as List<dynamic>) {
          if (value is Map<String, dynamic>) {
            loaded.add(OfflineItem.fromJson(value));
          }
        }
      } on FormatException {
        // Corrupted metadata may be recovered by re-downloading public files.
      } on TypeError {
        // Never display an unknown format.
      }
    }
    if (revision != _revision) return;
    _owner = owner;
    _items = List.unmodifiable(loaded);
    notifyListeners();
  }

  void close() {
    cancel();
    ++_revision;
    _owner = null;
    _items = const [];
    notifyListeners();
  }

  Future<void> _persist(String owner, List<OfflineItem> items) async {
    final prefs = await _prefs;
    if (!await prefs.setString(
      _key(owner),
      jsonEncode(items.map((item) => item.toJson()).toList()),
    )) {
      throw StateError('সংরক্ষিত ফাইলের তালিকা আপডেট করা যায়নি।');
    }
  }

  bool contains(String id) => _items.any((item) => item.id == id);
  OfflineItem? find(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void cancel() {
    _cancel = true;
    notifyListeners();
  }

  Future<void> download(ContentResource resource) async {
    final owner = _owner;
    if (owner == null) throw StateError('অফলাইন লাইব্রেরি চালু হয়নি।');
    if (_busy) throw StateError('আগের ডাউনলোডটি শেষ করুন।');
    if (contains(resource.id)) return;
    // Reserve the slot before asynchronously reading rights. Rapid taps
    // cannot start multiple downloads or overwrite each other's metadata.
    final revision = _revision;
    _busy = true;
    _cancel = false;
    _activeTitle = resource.titleBn?.trim().isNotEmpty == true
        ? resource.titleBn!
        : resource.title;
    _progress = 0;
    notifyListeners();
    http.Client? client;
    try {
      final allowed = await _authorizedAudioUrls();
      if (_owner != owner || _revision != revision || _cancel) {
        throw StateError('ডাউনলোড বাতিল করা হয়েছে।');
      }
      if (!canSaveOffline(resource, ownerAuthorizedAudioUrls: allowed)) {
        throw StateError('এই ফাইল অফলাইনে সংরক্ষণের অনুমতি নেই।');
      }
      final target = resolveResourceMedia(resource.linkedResource)!;
      final uri = target.uri!;
      client = _clientFactory();
      // The publisher omits browser CORS headers. For the 19 vetted,
      // owner-attested recordings, authenticated web requests use a
      // budget-limited Sukun Edge Function instead. No third-party URL is
      // forwarded to the gateway, only the published CMS resource ID.
      var downloadUri = uri;
      final requestHeaders = <String, String>{};
      if (kIsWeb && useWebMediaGateway) {
        // Fail closed if an approved Web MP3 has no configured backend or
        // authenticated user. Never silently try the publisher without CORS.
        final request = approvedWebAudioRequest(
          isWeb: true,
          source: uri,
          resourceId: resource.id,
          pinnedUrls: allowed,
          backendUrl: AppEnvironment.supabaseUrl,
          publishableKey: AppEnvironment.supabasePublishableKey,
          accessToken: AppEnvironment.isSupabaseConfigured
              ? Supabase.instance.client.auth.currentSession?.accessToken
              : null,
        );
        if (request != null) {
          downloadUri = request.uri;
          requestHeaders.addAll(request.headers);
        }
      }
      final request = http.Request('GET', downloadUri);
      request.headers.addAll(requestHeaders);
      request.followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        if (downloadUri != uri && response.statusCode == 401) {
          throw StateError('অফলাইন ডাউনলোডের জন্য আবার লগইন করুন।');
        }
        if (downloadUri != uri && response.statusCode == 429) {
          throw StateError('আজকের অডিও ডাউনলোড সীমা শেষ হয়েছে।');
        }
        throw StateError('অডিও/PDF সার্ভার ফাইলটি পাঠায়নি।');
      }
      final length = response.contentLength;
      if (length != null && length > maxFileBytes) {
        throw StateError('ফাইলটি ১০০ MB সীমার বেশি।');
      }
      final collected = BytesBuilder(copy: false);
      var count = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 40),
      )) {
        if (_cancel || _owner != owner || _revision != revision) {
          throw StateError('ডাউনলোড বাতিল করা হয়েছে।');
        }
        count += chunk.length;
        if (count > maxFileBytes) {
          throw StateError('ফাইলটি ১০০ MB সীমার বেশি।');
        }
        collected.add(chunk);
        _progress = length != null && length > 0
            ? (count / length).clamp(0.0, 1.0)
            : null;
        notifyListeners();
      }
      final result = collected.takeBytes();
      if (result.isEmpty || (length != null && result.length != length)) {
        throw StateError('ফাইলটি সম্পূর্ণ আসেনি।');
      }
      if (target.kind == ResourceMediaKind.pdf) {
        if (result.length < 5 ||
            result[0] != 0x25 ||
            result[1] != 0x50 ||
            result[2] != 0x44 ||
            result[3] != 0x46 ||
            result[4] != 0x2d) {
          throw StateError('এটি PDF ফাইল নয়।');
        }
      } else if (!(result.length > 3 &&
          ((result[0] == 0x49 && result[1] == 0x44 && result[2] == 0x33) ||
              (result[0] == 0xff && (result[1] & 0xe0) == 0xe0)))) {
        throw StateError('এটি MP3 অডিও ফাইল নয়।');
      }
      if (_cancel || _owner != owner || _revision != revision) {
        throw StateError('ডাউনলোড বাতিল করা হয়েছে।');
      }
      final key = _byteKey(owner, resource.id);
      try {
        await _bytes.write(key, result);
      } catch (error) {
        // Browser quota / disk-full writes must not create phantom downloads.
        // Do not treat a failure as a successful offline save.
        throw StateError(
          'ডিভাইস বা ব্রাউজারের স্টোরেজে ফাইলটি রাখা যায়নি। '
          'জায়গা খালি করে আবার চেষ্টা করুন।',
        );
      }
      // Identity switches during the storage write must not commit stale media.
      if (_cancel || _owner != owner || _revision != revision) {
        await _bytes.delete(key);
        throw StateError('ডাউনলোড বাতিল করা হয়েছে।');
      }
      final record = OfflineItem(
        id: resource.id,
        title: _activeTitle!,
        kind: target.kind == ResourceMediaKind.audio ? 'audio' : 'pdf',
        size: result.length,
        digest: sha256.convert(result).toString(),
        savedAt: DateTime.now().toUtc(),
      );
      final next = [..._items, record];
      try {
        await _persist(owner, next);
      } catch (_) {
        await _bytes.delete(key);
        rethrow;
      }
      if (_owner == owner) _items = List.unmodifiable(next);
    } finally {
      client?.close();
      _busy = false;
      _progress = null;
      _activeTitle = null;
      notifyListeners();
    }
  }

  /// Read from local storage only; offline playback never fetches Supabase.
  /// SHA-256 catches evicted/truncated/tampered files before opening.
  Future<Uint8List?> read(String id) async {
    final owner = _owner;
    final item = find(id);
    if (owner == null || item == null) return null;
    final revision = _revision;
    final bytes = await _bytes.read(_byteKey(owner, id));
    if (_owner != owner || revision != _revision) return null;
    if (bytes == null ||
        bytes.length != item.size ||
        sha256.convert(bytes).toString() != item.digest) {
      await remove(id);
      return null;
    }
    return bytes;
  }

  Future<void> remove(String id) async {
    final owner = _owner;
    if (owner == null) return;
    final revision = _revision;
    final next = _items.where((item) => item.id != id).toList();
    await _bytes.delete(_byteKey(owner, id));
    await _persist(owner, next);
    if (_owner == owner && _revision == revision) {
      _items = List.unmodifiable(next);
      notifyListeners();
    }
  }
}
