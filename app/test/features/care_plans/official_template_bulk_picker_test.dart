import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/presentation/official_template_bulk_picker.dart';

void main() {
  testWidgets(
    'category selection survives search and imports one combined batch',
    (tester) async {
      var selected = <String>{};
      final imported = <Set<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => OfficialTemplateBulkPicker(
                importedIds: const {'a02'},
                selectedIds: selected,
                onSelectionChanged: (ids) => setState(() => selected = ids),
                onImport: () => imported.add({...selected}),
                working: false,
              ),
            ),
          ),
        ),
      );
      final search = find.byKey(const Key('official-template-search'));
      await tester.enterText(search, 'কাজের শুরুতে');
      await tester.pumpAndSettle();
      await tester.tap(find.text('শুধু অনুসন্ধানের ফল নির্বাচন'));
      await tester.pumpAndSettle();
      expect(selected, {'a03'});

      await tester.enterText(search, 'গোসল');
      await tester.pumpAndSettle();
      final selectBath = find.byKey(const Key('select-category-bath'));
      await tester.ensureVisible(selectBath);
      await tester.tap(selectBath);
      await tester.pumpAndSettle();
      final baths = officialPrescriptionTemplates
          .where((item) => item.category == 'bath')
          .map((item) => item.id);
      expect(selected, {'a03', ...baths});
      await tester.tap(find.text('বিভাগের নির্বাচন বাতিল').first);
      await tester.pumpAndSettle();
      expect(selected, {'a03'});

      await tester.enterText(search, 'কাজের শুরুতে');
      await tester.pumpAndSettle();
      final selectAmal = find.byKey(const Key('select-category-amal'));
      await tester.ensureVisible(selectAmal);
      await tester.tap(selectAmal);
      await tester.pumpAndSettle();
      expect(selected, isNot(contains('a02')));
      expect(
        selected.length,
        officialPrescriptionTemplates
                .where((item) => item.category == 'amal')
                .length -
            1,
      );
      await tester.enterText(search, 'গোসল');
      await tester.pumpAndSettle();
      await tester.tap(selectBath);
      await tester.pumpAndSettle();
      expect(selected, containsAll(baths));
      await tester.tap(find.text('Import Selected (${selected.length})'));
      expect(imported, [selected]);
    },
  );
}
