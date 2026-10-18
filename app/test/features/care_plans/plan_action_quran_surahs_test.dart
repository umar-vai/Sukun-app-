import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

void main() {
  test(
    'approved action exposes canonical chapter route without copied text',
    () {
      final action = PlanAction.fromJson({
        'id': 'action-1',
        'care_plan_id': 'plan-1',
        'type': 'quran',
        'title': 'সূরা পড়ুন',
        'frequency_rule': {'type': 'daily', 'interval': 1},
        'start_date': '2026-10-18',
        'sort_order': 0,
        'review_status': 'approved',
        'reminder_enabled': false,
        'plan_action_quran_surahs': [
          {'surah_number': 114, 'title': 'An-Nas — আন-নাস', 'sort_order': 0},
        ],
      });

      expect(action.linkedResources, hasLength(1));
      expect(action.linkedResources.single.id, 'quran:114');
      expect(action.linkedResources.single.publicRoute, '/resources/quran/114');
      expect(action.linkedResources.single.canOpen, isTrue);
    },
  );
}
