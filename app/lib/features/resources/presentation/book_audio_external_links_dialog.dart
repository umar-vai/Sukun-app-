import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sukun_life/features/content_admin/domain/book_audio_source_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owner-licensed, publisher-hosted audio links streamed using the existing
/// Flutter audio player. No redundant MP3 upload or second audio player.
class BookAudioExternalLinksDialog extends StatefulWidget {
  const BookAudioExternalLinksDialog({super.key});

  @override
  State<BookAudioExternalLinksDialog> createState() =>
      _BookAudioExternalLinksDialogState();
}

class _BookAudioExternalLinksDialogState
    extends State<BookAudioExternalLinksDialog> {
  late final Future<List<BookAudioSourceCandidate>> _sources = _load();

  Future<List<BookAudioSourceCandidate>> _load() async {
    final text = await rootBundle.loadString(
      'assets/data/ruqyahbd_book_audio_crosswalk.json',
    );
    return parseBookAudioCatalog(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('রুকইয়াহ অডিও শুনুন'),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .65,
        child: FutureBuilder<List<BookAudioSourceCandidate>>(
          future: _sources,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('অডিওর উৎস তালিকা এখন খোলা যাচ্ছে না।');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tracks = snapshot.data!;
            return Column(
              children: [
                const Text(
                  'বইয়ে উল্লেখিত রুকইয়াহ অডিওগুলো শুনতে পছন্দের অডিওতে চাপ দিন।',
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = tracks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.titleBn),
                        subtitle: const Text('অডিও শুনুন · রুকইয়াহ সাপোর্ট বিডি'),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new_rounded),
                          tooltip: 'মূল উৎস খুলুন',
                          onPressed: () => launchUrl(
                            Uri.parse(entry.sourcePage),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerScreen(
                              resource: LinkedResource(
                                id: entry.id,
                                title: entry.titleBn,
                                titleBn: entry.titleBn,
                                type: 'audio',
                                mediaSourceType: 'direct_audio_url',
                                mediaUrl: entry.externalMediaUrl,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('বন্ধ করুন'),
        ),
      ],
    );
  }
}
