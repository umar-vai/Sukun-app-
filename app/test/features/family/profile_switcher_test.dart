import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/features/family/data/family_providers.dart';
import 'package:sukun_life/features/family/domain/family_profile.dart';
import 'package:sukun_life/features/family/presentation/profile_scope.dart';
import 'package:sukun_life/features/family/presentation/profile_switcher.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';

import 'family_test_support.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<FamilyProfile> profiles, {
    Size size = const Size(390, 844),
    double textScale = 1,
    MemoryActiveProfileStore? store,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scope = ProviderScope(
      overrides: familyOverrides(profiles, store: store),
      child: MaterialApp(
        theme: SukunTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ProfileScoped(
          child: PatientScaffold(
            title: 'আজকের কাজ',
            selectedIndex: 0,
            body: Center(child: Text('body')),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.text('body')));
  }

  testWidgets('single patient account shows no switcher at all', (
    tester,
  ) async {
    await pump(tester, [profile('only', 'Solo Patient', primary: true)]);
    expect(find.byKey(const Key('profile-switcher')), findsNothing);
    expect(find.byTooltip(profileSwitchLabelBn), findsNothing);
    // The rest of the app bar is unchanged.
    expect(find.byTooltip('আমার বার্তা'), findsOneWidget);
    expect(find.text('আজকের কাজ'), findsOneWidget);
  });

  testWidgets('five-profile family: switcher, sheet, check, disclosure', (
    tester,
  ) async {
    await pump(tester, fiveProfileFamily());

    expect(find.byKey(const Key('profile-switcher')), findsOneWidget);
    // Initials avatar of the owner profile in the app bar.
    expect(find.text('RU'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-switcher')));
    await tester.pumpAndSettle();

    expect(find.text(familyProfilesTitleBn), findsOneWidget);
    expect(find.text(profileSwitchLabelBn), findsOneWidget);
    expect(find.text('ফ্যামিলি প্রোফাইল'), findsOneWidget);
    expect(find.text('প্রোফাইল পরিবর্তন'), findsOneWidget);
    for (final p in fiveProfileFamily()) {
      final row = find.byKey(Key('profile-row-${p.patientId}'));
      await tester.scrollUntilVisible(row, 80);
      expect(row, findsOneWidget);
      expect(find.text(p.fullName), findsWidgets);
    }
    expect(find.text('স্ত্রী'), findsOneWidget);
    expect(find.text('বাবা'), findsOneWidget);
    // Back to the top to check the current profile marker.
    await tester.drag(find.byType(ListView).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    // Exactly one check, on the current (owner) row.
    expect(find.byKey(const Key('profile-selected-check')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-row-p-owner')),
        matching: find.byKey(const Key('profile-selected-check')),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('family-disclosure')),
      80,
    );
    expect(find.byKey(const Key('family-disclosure')), findsOneWidget);
    expect(find.text(familyDisclosureBn), findsOneWidget);
  });

  testWidgets('choosing a profile switches, moves the check and persists', (
    tester,
  ) async {
    final store = MemoryActiveProfileStore();
    final container = await pump(tester, fiveProfileFamily(), store: store);

    await tester.tap(find.byKey(const Key('profile-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-row-p-child2')));
    await tester.pumpAndSettle();

    expect(container.read(activePatientIdProvider), 'p-child2');
    expect(store.values[testUserId], 'p-child2');
    // The sheet closed and the app bar avatar now shows the new profile.
    expect(find.text(familyProfilesTitleBn), findsNothing);
    expect(find.text('MR'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-switcher')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-row-p-child2')),
        matching: find.byKey(const Key('profile-selected-check')),
      ),
      findsOneWidget,
    );
  });

  for (final (name, size, scale) in <(String, Size, double)>[
    ('compact phone 320x568', const Size(320, 568), 1.0),
    ('compact phone, large text', const Size(320, 568), 1.6),
    ('large phone 430x932', const Size(430, 932), 1.0),
  ]) {
    testWidgets('long Bangla names never overflow on $name', (tester) async {
      final profiles = [
        profile(
          'p-owner',
          'মুহাম্মদ আব্দুর রহমান আল মাহমুদ চৌধুরী সিদ্দিকী',
          primary: true,
        ),
        profile(
          'p-2',
          'সৈয়দা ফাতেমাতুজ জোহরা খানম ইসলামাবাদী',
          relationship: 'স্ত্রী ও পরিবারের প্রধান যত্নদাতা সদস্য',
          order: 1,
        ),
        for (var i = 3; i <= 5; i++)
          profile('p-$i', 'সন্তান নম্বর $i আব্দুল্লাহ', order: i),
      ];
      await pump(tester, profiles, size: size, textScale: scale);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('profile-switcher')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The list scrolls rather than overflowing; the last row is reachable.
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-row-p-5')),
        120,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.takeException(), isNull);
      // The disclosure is reachable at the end of the same scroll view.
      await tester.scrollUntilVisible(
        find.byKey(const Key('family-disclosure')),
        120,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const Key('family-disclosure')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
