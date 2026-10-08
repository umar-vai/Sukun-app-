import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resource_paging.dart';

void main() {
  test('reads a resource after the old 1,000-row cutoff', () async {
    final ids = List<int>.generate(1205, (index) => index + 1);
    final calls = <String>[];
    final result = await fetchAllResourcePages<int>(
      pageSize: 500,
      loadPage: (from, to) async {
        calls.add('$from..$to');
        return ids.skip(from).take(to - from + 1).toList();
      },
    );

    expect(result, orderedEquals(ids));
    expect(result.last, 1205);
    expect(result.toSet().length, ids.length);
    expect(calls, ['0..499', '500..999', '1000..1499']);
  });

  test('requests the next page when exactly full', () async {
    final ids = List<int>.generate(1000, (index) => index);
    final calls = <int>[];
    final result = await fetchAllResourcePages<int>(
      pageSize: 500,
      loadPage: (from, to) async {
        calls.add(from);
        return ids.skip(from).take(to - from + 1).toList();
      },
    );

    expect(result.length, 1000);
    expect(calls, [0, 500, 1000]);
  });

  test('empty data returns an empty list without pagination loop', () async {
    var calls = 0;
    final result = await fetchAllResourcePages<int>(
      pageSize: 500,
      loadPage: (from, to) async {
        calls++;
        return [];
      },
    );
    expect(result, isEmpty);
    expect(calls, 1);
  });

  test(
    'backend failure is surfaced instead of returning partial results',
    () async {
      expect(
        () => fetchAllResourcePages<int>(
          pageSize: 500,
          loadPage: (from, to) async {
            if (from >= 500) throw StateError('Network failure');
            return List<int>.generate(500, (index) => index);
          },
        ),
        throwsStateError,
      );
    },
  );

  test('a backend cannot return more than the requested page', () async {
    expect(
      () => fetchAllResourcePages<int>(
        pageSize: 5,
        loadPage: (from, to) async => [0, 1, 2, 3, 4, 5],
      ),
      throwsStateError,
    );
  });
}
