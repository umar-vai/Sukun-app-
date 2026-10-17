import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reuses the existing verified canonical Quran Edge API. No verse text,
/// translation or audio file is copied to the Sukun database.
Future<int?> showPersonalSurahPicker({
  required BuildContext context,
  required Set<int> exclude,
}) => showModalBottomSheet<int>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _PersonalSurahPicker(exclude: exclude),
);

int? quranNumberFromRef(String? reference) {
  if (reference == null || !reference.startsWith('quran:')) return null;
  final number = int.tryParse(reference.substring('quran:'.length));
  return number != null && number >= 1 && number <= 114 ? number : null;
}

class _PersonalSurahPicker extends StatefulWidget {
  const _PersonalSurahPicker({required this.exclude});
  final Set<int> exclude;

  @override
  State<_PersonalSurahPicker> createState() => _PersonalSurahPickerState();
}

class _PersonalSurahPickerState extends State<_PersonalSurahPicker> {
  String _search = '';
  late final Future<List<Map<String, dynamic>>> _surahs = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await Supabase.instance.client.functions.invoke(
      'quran-content',
      body: {'action': 'chapters'},
    );
    if (response.data is! Map) {
      throw const FormatException('Quran catalog unavailable');
    }
    final raw = (response.data as Map)['chapters'];
    if (raw is! List) throw const FormatException('Missing Surah list');
    final chapters = raw
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .where(
          (chapter) =>
              chapter['id'] is int &&
              (chapter['id'] as int) >= 1 &&
              (chapter['id'] as int) <= 114,
        )
        .toList(growable: false);
    if (chapters.length != 114) {
      throw const FormatException('Canonical 114 Surah list is incomplete');
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .88,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'কুরআন থেকে সূরা নির্বাচন',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                '১১৪ সূরার মূল API ক্যাটালগ — আলাদা করে কোনো আয়াত সংরক্ষণ হবে না।',
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'সূরার নাম বা নম্বর দিয়ে খুঁজুন',
                ),
                onChanged: (value) =>
                    setState(() => _search = value.toLowerCase().trim()),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _surahs,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'সূরার তালিকা আনা যাচ্ছে না। ইন্টারনেট সংযোগ যাচাই করুন।',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final visible = snapshot.data!
                  .where((surah) {
                    final number = surah['id'] as int;
                    if (widget.exclude.contains(number)) return false;
                    final name = (surah['name_simple'] ?? '')
                        .toString()
                        .toLowerCase();
                    final arabic = (surah['name_arabic'] ?? '').toString();
                    return _search.isEmpty ||
                        number.toString().contains(_search) ||
                        name.contains(_search) ||
                        arabic.contains(_search);
                  })
                  .toList(growable: false);
              return ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final item = visible[index];
                  final number = item['id'] as int;
                  return ListTile(
                    leading: CircleAvatar(child: Text('$number')),
                    title: Text(
                      item['name_simple']?.toString() ?? 'সূরা $number',
                    ),
                    subtitle: Text(item['name_arabic']?.toString() ?? ''),
                    onTap: () => Navigator.pop(context, number),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
