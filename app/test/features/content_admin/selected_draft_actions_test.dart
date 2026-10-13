import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/domain/selected_draft_actions.dart';

void main() {
  test('empty selection sends no RPC chunks', () {
    expect(splitDraftBatch(<String>[]), isEmpty);
  });

  test('all selected items are chunked with a safe database upper bound', () {
    final ids = List.generate(205, (i) => 'draft-$i');
    final chunks = splitDraftBatch(ids);
    expect(chunks.map((items) => items.length).toList(), [80, 80, 45]);
    expect(chunks.expand((items) => items).toList(), ids);
  });

  test('invalid chunk sizes cannot overflow the server side limit', () {
    expect(() => splitDraftBatch(['a'], batchSize: 0), throwsArgumentError);
    expect(() => splitDraftBatch(['a'], batchSize: 101), throwsArgumentError);
  });

  test('one selected item creates one batch', () {
    expect(splitDraftBatch(['selected-one']), [
      ['selected-one'],
    ]);
  });
}
