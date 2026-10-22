import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Saved playlists contain IDs only. Never cache clinical content or URLs in
/// unencrypted preferences; every track is re-authorized before streaming.
final playlistLibraryProvider = Provider<PlaylistLibrary>((ref) {
  final library = PlaylistLibrary();
  ref.onDispose(library.dispose);
  return library;
});

@immutable
class SavedPlaylist {
  const SavedPlaylist({
    required this.id,
    required this.name,
    required this.resourceIds,
  });

  final String id;
  final String name;
  final List<String> resourceIds;

  factory SavedPlaylist.fromJson(Map<String, dynamic> json) => SavedPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        resourceIds: List<String>.unmodifiable(
          (json['resources'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .where((id) => id.isNotEmpty),
        ),
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'resources': resourceIds,
      };

  SavedPlaylist withResources(List<String> ids) => SavedPlaylist(
        id: id,
        name: name,
        resourceIds: List.unmodifiable(ids),
      );

  SavedPlaylist renamed(String nextName) => SavedPlaylist(
        id: id,
        name: nextName,
        resourceIds: resourceIds,
      );
}

/// Private to a browser installation/device and scoped by verified user id.
/// Does NOT sync across devices. Never reuses the previous owner's state.
class PlaylistLibrary extends ChangeNotifier {
  PlaylistLibrary({Future<SharedPreferences>? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferences;
  String? _owner;
  List<SavedPlaylist> _playlists = const [];
  int _revision = 0;
  Future<void> _writes = Future<void>.value();

  bool get ready => _owner != null;
  List<SavedPlaylist> get playlists => List.unmodifiable(_playlists);

  String _key(String owner) => 'sukun.playlists.v1.${Uri.encodeComponent(owner)}';

  Future<void> open(String owner) async {
    if (_owner == owner) return;
    final revision = ++_revision;
    _owner = null;
    _playlists = const [];
    notifyListeners();
    final prefs = await _preferences;
    final raw = prefs.getString(_key(owner));
    final loaded = <SavedPlaylist>[];
    if (raw != null) {
      try {
        final values = jsonDecode(raw) as List<dynamic>;
        for (final value in values) {
          if (value is Map<String, dynamic>) {
            loaded.add(SavedPlaylist.fromJson(value));
          }
        }
      } on FormatException {
        // Corrupt local settings must not crash the resource library.
      } on TypeError {
        // Malformed old versions are intentionally ignored.
      }
    }
    if (revision != _revision) return;
    _owner = owner;
    _playlists = List.unmodifiable(loaded);
    notifyListeners();
  }

  void close() {
    ++_revision;
    _owner = null;
    _playlists = const [];
    notifyListeners();
  }

  void _commit(List<SavedPlaylist> next) {
    final owner = _owner;
    if (owner == null) throw StateError('Playlist identity not loaded.');
    _playlists = List.unmodifiable(next);
    final snapshot = jsonEncode(_playlists.map((p) => p.toJson()).toList());
    final key = _key(owner);
    _writes = _writes.then((_) async {
      final prefs = await _preferences;
      final saved = await prefs.setString(key, snapshot);
      if (!saved) throw StateError('Could not save playlist.');
    });
    notifyListeners();
  }

  Future<void> flush() => _writes;

  String create(String name, {String? resourceId}) {
    final title = name.trim();
    if (title.isEmpty || title.length > 60) {
      throw ArgumentError('প্লেলিস্টের নাম ১–৬০ অক্ষরের হতে হবে।');
    }
    final id = const Uuid().v4();
    _commit([
      ..._playlists,
      SavedPlaylist(
        id: id,
        name: title,
        resourceIds: resourceId == null ? const [] : [resourceId],
      ),
    ]);
    return id;
  }

  void rename(String id, String name) {
    final next = name.trim();
    if (next.isEmpty || next.length > 60) throw ArgumentError('সঠিক নাম দিন।');
    _commit([
      for (final p in _playlists) p.id == id ? p.renamed(next) : p,
    ]);
  }

  void remove(String id) {
    _commit(_playlists.where((p) => p.id != id).toList());
  }

  void add(String playlistId, String resourceId) {
    if (resourceId.trim().isEmpty) return;
    _commit([
      for (final p in _playlists)
        p.id == playlistId && !p.resourceIds.contains(resourceId)
            ? p.withResources([...p.resourceIds, resourceId])
            : p,
    ]);
  }

  void removeTrack(String playlistId, String resourceId) {
    _commit([
      for (final p in _playlists)
        p.id == playlistId
            ? p.withResources(
                p.resourceIds.where((id) => id != resourceId).toList(),
              )
            : p,
    ]);
  }

  void move(String playlistId, int oldIndex, int newIndex) {
    _commit([
      for (final p in _playlists)
        if (p.id == playlistId)
          p.withResources(_reorder(p.resourceIds, oldIndex, newIndex))
        else
          p,
    ]);
  }

  static List<String> _reorder(List<String> items, int from, int to) {
    if (from < 0 || from >= items.length || to < 0 || to >= items.length) {
      return items;
    }
    final result = List<String>.from(items);
    result.insert(to, result.removeAt(from));
    return result;
  }
}
