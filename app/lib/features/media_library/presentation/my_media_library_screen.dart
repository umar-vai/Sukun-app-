import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/media_library/data/local_audio_uri.dart';
import 'package:sukun_life/features/media_library/data/offline_library.dart';
import 'package:sukun_life/features/media_library/data/playlist_library.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

class MyMediaLibraryScreen extends ConsumerStatefulWidget {
  const MyMediaLibraryScreen({super.key, this.addResourceId, this.downloadId});

  final String? addResourceId;
  final String? downloadId;

  @override
  ConsumerState<MyMediaLibraryScreen> createState() =>
      _MyMediaLibraryScreenState();
}

class _MyMediaLibraryScreenState extends ConsumerState<MyMediaLibraryScreen> {
  int _tab = 0;
  late Future<ContentResource?> _candidate;
  late Future<Set<String>> _allowedAudio;
  final Map<String, Future<ContentResource?>> _titles = {};
  String? _currentOwner;

  @override
  void initState() {
    super.initState();
    _candidate = _fetchCandidate();
    _allowedAudio = ownerAuthorizedAudioUrls();
    _tab = widget.downloadId != null ? 1 : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openForIdentity();
    });
  }

  Future<ContentResource?> _fetchCandidate() async {
    final id = widget.addResourceId ?? widget.downloadId;
    if (id == null) return null;
    return ref.read(resourcesRepositoryProvider).getResource(id);
  }

  void _openForIdentity() {
    final identity = ref.read(appSessionProvider).value?.userId ?? 'guest';
    if (_currentOwner != identity) {
      _currentOwner = identity;
      _titles.clear();
      if (widget.addResourceId != null || widget.downloadId != null) {
        _candidate = _fetchCandidate();
      }
      if (mounted) setState(() {});
    }
    unawaited(ref.read(playlistLibraryProvider).open(identity));
    unawaited(ref.read(offlineLibraryProvider).open(identity));
  }

  Future<ContentResource?> _titleFor(String id) =>
      _titles.putIfAbsent(id, () =>
          ref.read(resourcesRepositoryProvider).getResource(id));

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<String?> _nameDialog({String? initial}) async {
    final input = TextEditingController(text: initial);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(initial == null ? 'নতুন প্লেলিস্ট' : 'নাম পরিবর্তন'),
          content: TextField(
            controller: input,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(hintText: 'প্লেলিস্টের নাম'),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(dialogContext).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(input.text.trim()),
              child: const Text('সংরক্ষণ'),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Future<void> _create({String? resourceId}) async {
    final title = await _nameDialog();
    if (title == null || title.isEmpty) return;
    try {
      final library = ref.read(playlistLibraryProvider);
      library.create(title, resourceId: resourceId);
      await library.flush();
      _message('প্লেলিস্ট সংরক্ষিত হয়েছে।');
    } catch (_) {
      _message('প্লেলিস্ট সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।');
    }
  }

  Future<void> _rename(SavedPlaylist playlist) async {
    final name = await _nameDialog(initial: playlist.name);
    if (name == null || name.isEmpty || name == playlist.name) return;
    try {
      final library = ref.read(playlistLibraryProvider);
      library.rename(playlist.id, name);
      await library.flush();
    } catch (_) {
      _message('নাম সংরক্ষণ করা যায়নি।');
    }
  }

  Future<void> _startPlaylist(SavedPlaylist playlist) async {
    final identityAtStart = ref.read(appSessionProvider).value?.userId;
    final controller = ref.read(audioPlaybackControllerProvider);
    final offline = ref.read(offlineLibraryProvider);
    final repository = ref.read(resourcesRepositoryProvider);
    final resources = <LinkedResource>[];
    final localUris = <String, Uri>{};
    final handles = <LocalAudioUri>[];
    var ownershipTransferred = false;
    try {
      for (final id in playlist.resourceIds) {
        final saved = offline.find(id);
        if (saved?.kind == 'audio') {
          final bytes = await offline.read(id);
          if (bytes != null) {
            final handle = await createLocalAudioUri(bytes);
            handles.add(handle);
            localUris[id] = handle.uri;
            resources.add(
              LinkedResource(id: id, title: saved!.title, type: 'audio'),
            );
            continue;
          }
        }
        // A stored ID is never sufficient for access; enforce backend RLS
        // and published status every time before streaming.
        ContentResource? current;
        try {
          current = await repository.getResource(id);
        } catch (_) {
          // Offline mode can play only previously downloaded public tracks.
        }
        if (current != null &&
            current.type == 'audio' &&
            current.status == 'published' &&
            current.visibility == 'public' &&
            resolveResourceMedia(current.linkedResource)?.kind ==
                ResourceMediaKind.audio) {
          resources.add(current.linkedResource);
        }
      }
      if (resources.isEmpty) {
        throw StateError('প্লেলিস্টের অডিও পাওয়া যায়নি।');
      }
      if (identityAtStart != ref.read(appSessionProvider).value?.userId) {
        throw StateError('Account changed during playlist preparation.');
      }
      await controller.loadPlaylist(
        title: playlist.name,
        resources: resources,
        localUris: localUris,
        handles: handles,
      );
      ownershipTransferred = true;
      controller.resumeCurrent();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const _PlaylistPlayerPage()),
      );
      if (resources.length < playlist.resourceIds.length) {
        _message('কিছু অডিও অনুপলব্ধ থাকায় বাদ দেওয়া হয়েছে।');
      }
    } catch (_) {
      _message('প্লেলিস্ট চালু হয়নি। নেটওয়ার্ক বা সংরক্ষিত অডিও দেখুন।');
    } finally {
      if (!ownershipTransferred) {
        for (final handle in handles) {
          handle.dispose();
        }
      }
    }
  }

  Future<void> _openOffline(OfflineItem item) async {
    try {
      final library = ref.read(offlineLibraryProvider);
      final bytes = await library.read(item.id);
      if (bytes == null) throw StateError('ফাইল নেই');
      if (!mounted) return;
      if (item.kind == 'pdf') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(item.title)),
              body: PdfViewer.data(
                bytes,
                sourceName: 'sukun-offline-${item.id}.pdf',
              ),
            ),
          ),
        );
      } else {
        final handle = await createLocalAudioUri(bytes);
        await ref
            .read(audioPlaybackControllerProvider)
            .loadPlaylist(
              title: item.title,
              resources: [
                LinkedResource(id: item.id, title: item.title, type: 'audio'),
              ],
              localUris: {item.id: handle.uri},
              handles: [handle],
            );
        ref.read(audioPlaybackControllerProvider).resumeCurrent();
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const _PlaylistPlayerPage()),
        );
      }
    } catch (_) {
      _message('সংরক্ষিত ফাইলটি খোলা যায়নি। আবার ডাউনলোড করুন।');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSessionProvider, (previous, next) => _openForIdentity());
    final library = ref.watch(playlistLibraryProvider);
    final offline = ref.watch(offlineLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('আমার অডিও ও ডাউনলোড')),
      body: AnimatedBuilder(
        animation: Listenable.merge([library, offline]),
        builder: (context, _) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('প্লেলিস্ট'),
                      icon: Icon(Icons.queue_music),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('ডাউনলোড'),
                      icon: Icon(Icons.download_done),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (values) =>
                      setState(() => _tab = values.first),
                ),
              ),
              if (!library.ready || !offline.ready)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: _tab == 0
                      ? _playlists(library, offline)
                      : _downloads(offline),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playlists(PlaylistLibrary library, OfflineLibrary offline) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (widget.addResourceId != null)
          FutureBuilder<ContentResource?>(
            future: _candidate,
            builder: (context, snapshot) {
              final resource = snapshot.data;
              if (resource?.type != 'audio' ||
                  resource?.status != 'published' ||
                  resource?.visibility != 'public') {
                return const ListTile(
                  title: Text(
                    'অডিওটি পাওয়া গেলে প্লেলিস্টে যুক্ত করতে পারবেন।',
                  ),
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(resource!.titleBn ?? resource.title),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        onPressed: () => _create(resourceId: resource.id),
                        label: const Text('নতুন প্লেলিস্টে যুক্ত করুন'),
                      ),
                      for (final playlist in library.playlists)
                        ListTile(
                          title: Text(playlist.name),
                          trailing: Icon(
                            playlist.resourceIds.contains(resource.id)
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                          ),
                          onTap: () async {
                            library.add(playlist.id, resource.id);
                            try {
                              await library.flush();
                            } catch (_) {
                              _message('প্লেলিস্ট সংরক্ষণ হয়নি।');
                              return;
                            }
                            _message('প্লেলিস্টে যুক্ত হয়েছে।');
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('নতুন প্লেলিস্ট তৈরি করুন'),
        ),
        const SizedBox(height: 12),
        if (library.playlists.isEmpty)
          const ListTile(
            title: Text('এখনো কোনো প্লেলিস্ট নেই'),
            subtitle: Text('অডিও খুলে “প্লেলিস্টে যুক্ত করুন” চাপুন।'),
          ),
        for (final playlist in library.playlists)
          Card(
            child: ExpansionTile(
              key: ValueKey(playlist.id),
              title: Text(playlist.name),
              subtitle: Text('${playlist.resourceIds.length}টি অডিও'),
              trailing: const Icon(Icons.expand_more),
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton.icon(
                      onPressed: playlist.resourceIds.isEmpty
                          ? null
                          : () => _startPlaylist(playlist),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('সবগুলো চালান'),
                    ),
                    TextButton.icon(
                      onPressed: () => _rename(playlist),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('নাম বদলান'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('প্লেলিস্ট মুছবেন?'),
                            content: const Text(
                              'এতে সংরক্ষিত অডিও ফাইল মুছে যাবে না।',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('না'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('মুছুন'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        library.remove(playlist.id);
                        try {
                          await library.flush();
                        } catch (_) {
                          _message('প্লেলিস্ট মুছতে সমস্যা হয়েছে।');
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('মুছুন'),
                    ),
                  ],
                ),
                for (var i = 0; i < playlist.resourceIds.length; i++)
                  ListTile(
                    title: FutureBuilder<ContentResource?>(
                      future: _titleFor(playlist.resourceIds[i]),
                      builder: (context, snapshot) {
                        final saved = offline.find(playlist.resourceIds[i]);
                        final resource = snapshot.data;
                        return Text(
                          saved?.title ??
                              resource?.titleBn ??
                              resource?.title ??
                              'অডিও ${i + 1} (অফলাইনে নেই)',
                        );
                      },
                    ),
                    leading: const Icon(Icons.music_note_outlined),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'উপরে নিন',
                          onPressed: i == 0
                              ? null
                              : () {
                                  library.move(playlist.id, i, i - 1);
                                  unawaited(library.flush());
                                },
                          icon: const Icon(Icons.arrow_upward, size: 20),
                        ),
                        IconButton(
                          tooltip: 'নিচে নিন',
                          onPressed: i == playlist.resourceIds.length - 1
                              ? null
                              : () {
                                  library.move(playlist.id, i, i + 1);
                                  unawaited(library.flush());
                                },
                          icon: const Icon(Icons.arrow_downward, size: 20),
                        ),
                        IconButton(
                          tooltip: 'বাদ দিন',
                          onPressed: () {
                            library.removeTrack(
                              playlist.id,
                              playlist.resourceIds[i],
                            );
                            unawaited(library.flush());
                          },
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _downloads(OfflineLibrary library) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Text(
          'ব্যবহৃত: ${(library.totalBytes / 1048576).toStringAsFixed(1)} MB / ২৫০ MB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (widget.downloadId != null)
          FutureBuilder<ContentResource?>(
            future: _candidate,
            builder: (context, snapshot) => FutureBuilder<Set<String>>(
              future: _allowedAudio,
              builder: (context, allowedSnapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    allowedSnapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                final resource = snapshot.data;
                final allowed = allowedSnapshot.data;
                if (resource == null ||
                    allowed == null ||
                    !canSaveOffline(
                      resource,
                      ownerAuthorizedAudioUrls: allowed,
                    )) {
                  return const ListTile(
                    title: Text('এই উপকরণ অফলাইন ডাউনলোডের জন্য অনুমোদিত নয়।'),
                    subtitle: Text(
                      'প্রকাশিত ও অনুমোদিত অডিও/PDF-ই সংরক্ষণ করা যায়।',
                    ),
                  );
                }
                return Card(
                  child: ListTile(
                    title: Text(resource.titleBn ?? resource.title),
                    subtitle: Text(
                      library.contains(resource.id)
                          ? 'ইতিমধ্যে সংরক্ষিত'
                          : 'অ্যাপের ভেতরে সংরক্ষণ করুন',
                    ),
                    trailing: FilledButton(
                      onPressed: library.busy || library.contains(resource.id)
                          ? null
                          : () async {
                              try {
                                await library.download(resource);
                                _message('অফলাইনে সংরক্ষিত হয়েছে।');
                              } catch (_) {
                                _message(
                                  'ডাউনলোড ব্যর্থ। নেটওয়ার্ক, অনুমতি বা জায়গা পরীক্ষা করুন।',
                                );
                              }
                            },
                      child: const Text('ডাউনলোড'),
                    ),
                  ),
                );
              },
            ),
          ),
        if (library.busy) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(library.activeTitle ?? 'ডাউনলোড হচ্ছে…'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: library.progress),
                  TextButton(
                    onPressed: library.cancel,
                    child: const Text('ডাউনলোড বাতিল করুন'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (library.items.isEmpty)
          const ListTile(
            title: Text('এখনো কিছু ডাউনলোড করা হয়নি'),
            subtitle: Text('অনুমোদিত অডিও বা PDF খুলে ডাউনলোড করুন।'),
          ),
        for (final item in library.items)
          Card(
            child: ListTile(
              leading: Icon(
                item.kind == 'audio'
                    ? Icons.headphones_outlined
                    : Icons.picture_as_pdf_outlined,
              ),
              title: Text(item.title),
              subtitle: Text(
                '${(item.size / 1048576).toStringAsFixed(1)} MB · অফলাইনে আছে',
              ),
              onTap: () => _openOffline(item),
              trailing: IconButton(
                tooltip: 'সংরক্ষিত ফাইল মুছুন',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  try {
                    await library.remove(item.id);
                  } catch (_) {
                    _message('ফাইল মুছতে সমস্যা হয়েছে।');
                  }
                },
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'শুধু এই ডিভাইসে ফাইল থাকবে। ব্রাউজার তার স্টোরেজ মুছে ফেলতে পারে। '
          'YouTube বা রোগীর ব্যক্তিগত নথি এখানে ডাউনলোড করা যায় না।',
        ),
      ],
    );
  }
}

class _PlaylistPlayerPage extends ConsumerWidget {
  const _PlaylistPlayerPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(audioPlaybackControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(controller.playlistTitle ?? 'অডিও প্লেয়ার')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final player = controller.player;
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.graphic_eq, size: 70),
                      const SizedBox(height: 16),
                      Text(
                        controller.currentTitle ?? 'অডিও',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'অডিও ${controller.playlistIndex + 1} / ${controller.playlistLength}',
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<Duration>(
                        stream: player.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final total = player.duration ?? Duration.zero;
                          final milliseconds = total.inMilliseconds;
                          return Column(
                            children: [
                              Slider(
                                value: milliseconds <= 0
                                    ? 0
                                    : (position.inMilliseconds / milliseconds)
                                          .clamp(0.0, 1.0),
                                onChanged: milliseconds <= 0
                                    ? null
                                    : (value) => controller.seek(
                                        Duration(
                                          milliseconds: (value * milliseconds)
                                              .round(),
                                        ),
                                      ),
                              ),
                              Text(
                                '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}'
                                ' / ${total.inMinutes}:${(total.inSeconds % 60).toString().padLeft(2, '0')}',
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, snapshot) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'আগের অডিও',
                              onPressed: player.hasPrevious
                                  ? controller.previous
                                  : null,
                              icon: const Icon(Icons.skip_previous, size: 36),
                            ),
                            IconButton.filled(
                              tooltip: player.playing ? 'বিরতি' : 'চালান',
                              onPressed: player.playing
                                  ? () => controller.pause()
                                  : controller.resumeCurrent,
                              icon: Icon(
                                player.playing ? Icons.pause : Icons.play_arrow,
                                size: 34,
                              ),
                            ),
                            IconButton(
                              tooltip: 'পরের অডিও',
                              onPressed: player.hasNext
                                  ? controller.next
                                  : null,
                              icon: const Icon(Icons.skip_next, size: 36),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final speed in const [1.0, 1.25, 1.5, 2.0])
                            ActionChip(
                              label: Text('${speed}x'),
                              onPressed: () => controller.setSpeed(speed),
                            ),
                          ActionChip(
                            label: const Text('১৫ মিনিটের টাইমার'),
                            onPressed: () => controller.setSleepTimer(15),
                          ),
                          ActionChip(
                            label: const Text('টাইমার বন্ধ'),
                            onPressed: () => controller.setSleepTimer(0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
