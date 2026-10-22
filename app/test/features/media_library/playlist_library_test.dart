import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/media_library/data/playlist_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('create, reorder, rename, remove and persist ordered playlists', () async {
    final library = PlaylistLibrary();
    await library.open('user-a');
    final id = library.create('সকাল', resourceId: 'one');
    library.add(id, 'two');
    library.add(id, 'two');
    library.move(id, 1, 0);
    library.rename(id, 'রুকইয়াহ');
    await library.flush();

    final recovered = PlaylistLibrary();
    await recovered.open('user-a');
    expect(recovered.playlists.single.name, 'রুকইয়াহ');
    expect(recovered.playlists.single.resourceIds, ['two', 'one']);

    recovered.removeTrack(id, 'one');
    await recovered.flush();
    recovered.remove(id);
    await recovered.flush();
    expect(recovered.playlists, isEmpty);
    library.dispose();
    recovered.dispose();
  });

  test('account change hides previous account without cross-owner leak', () async {
    final library = PlaylistLibrary();
    await library.open('patient-a');
    library.create('patient A library', resourceId: 'x');
    await library.flush();
    library.close();
    await library.open('patient-b');
    expect(library.playlists, isEmpty);
    await library.open('patient-a');
    expect(library.playlists.single.resourceIds, ['x']);
    library.dispose();
  });

  test('validation rejects blank and excessively long titles', () async {
    final library = PlaylistLibrary();
    await library.open('guest');
    expect(() => library.create('  '), throwsArgumentError);
    expect(() => library.create('x' * 61), throwsArgumentError);
    library.dispose();
  });
}
