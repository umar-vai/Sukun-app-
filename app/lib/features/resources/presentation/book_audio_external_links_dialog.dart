import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sukun_life/features/content_admin/domain/book_audio_source_catalog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public source index, not a mirror or a proxy. External site hosts audio.
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
      title: const Text('রুকইয়াহ অডিওর মূল উৎস'),
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
                  'বইয়ে উল্লেখিত অডিওর এই তালিকা Ruqyah Support BD-এর '
                  'ওয়েবসাইট থেকে সংগৃহীত উৎস লিংক। '
                  'Sukun Life অডিও ফাইলের মালিক বা হোস্ট নয়। '
                  'লিংকটি খুললে মূল ওয়েবসাইট/মিডিয়া খুলবে।',
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
                        subtitle: Text(
                          entry.requiresContextReview
                              ? 'বিশেষজ্ঞের পর্যালোচনা প্রয়োজন'
                              : 'Ruqyah Support BD · মূল অডিও লিংক',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new_rounded),
                          tooltip: 'মূল সাইটে অডিও খুলুন',
                          onPressed: () async {
                            final opened = await launchUrl(
                              Uri.parse(entry.externalMediaUrl),
                              mode: LaunchMode.externalApplication,
                            );
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'অডিও খুলতে সমস্যা হয়েছে। উৎস সাইটে চেষ্টা করুন।',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        onTap: () => launchUrl(
                          Uri.parse(entry.sourcePage),
                          mode: LaunchMode.externalApplication,
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
