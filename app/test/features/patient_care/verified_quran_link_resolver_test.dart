import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/domain/verified_quran_link_resolver.dart';

PlanAction action(String text) => PlanAction(
  id: 'test-action',
  carePlanId: 'approved-plan',
  type: 'recitation',
  title: text,
  frequency: const ActionFrequency.daily(),
  startDate: DateTime(2026, 10, 16),
  sortOrder: 0,
  reviewStatus: ActionReviewStatus.approved,
  reminderEnabled: true,
);

void main() {
  test('Ayatul Kursi links to Quran 2:255 without generating verse text', () {
    final links = verifiedQuranLinksForAction(action('আয়াতুল কুরসি পড়বেন'));
    expect(links, hasLength(1));
    expect(links.single.title, 'আয়াতুল কুরসি (২:২৫৫)');
    expect(links.single.route, '/resources/quran/2?ayah=255');
  });

  test('Surah Falaq and Nas become two independent canonical links', () {
    final links = verifiedQuranLinksForAction(
      action('সূরা ফালাক-নাস ৭ বার পড়বেন'),
    );
    expect(links.map((link) => link.surahNumber), [113, 114]);
    expect(links.map((link) => link.route), [
      '/resources/quran/113',
      '/resources/quran/114',
    ]);
  });

  test('no guessed Surah merely because the instruction says namaz', () {
    expect(
      verifiedQuranLinksForAction(action('প্রতি নামাজের পর তাসবিহ পড়বেন')),
      isEmpty,
    );
  });

  test('does not duplicate an already referenced Surah', () {
    final links = verifiedQuranLinksForAction(
      action('সূরা ফালাক এবং ফালাক-নাস পড়বেন'),
    );
    expect(links.map((link) => link.surahNumber), [113, 114]);
  });
}
