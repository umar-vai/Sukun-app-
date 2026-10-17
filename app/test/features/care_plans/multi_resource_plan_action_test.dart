import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

void main() {
  test('patient action parses every accessible published linked resource', () {
    final action = PlanAction.fromJson({
      'id': 'action-1',
      'care_plan_id': 'plan-1',
      'type': 'recitation',
      'title': 'Morning recitation',
      'frequency_rule': {'type': 'daily', 'interval': 1},
      'start_date': '2026-10-16',
      'sort_order': 0,
      'review_status': 'approved',
      'reminder_enabled': true,
      'plan_action_resources': [
        {
          'sort_order': 0,
          'usage_note': 'Read',
          'content_items': {
            'id': 'dua-2',
            'title': 'Dua',
            'type': 'dua',
            'visibility': 'patient_only',
            'status': 'published',
          },
        },
        {
          'sort_order': 1,
          'usage_note': null,
          'content_items': {
            'id': 'amal-1',
            'title': 'Amal',
            'type': 'amal',
            'visibility': 'public',
            'status': 'published',
          },
        },
        {
          'usage_note': null,
          'content_items': {
            'id': 'staff-hidden',
            'title': 'Staff secret',
            'type': 'dua',
            'visibility': 'staff_only',
            'status': 'published',
          },
        },
        {
          'usage_note': null,
          'content_items': {
            'id': 'unpublished',
            'title': 'Not published',
            'type': 'dua',
            'visibility': 'public',
            'status': 'review',
          },
        },
      ],
    });
    expect(action.linkedResources.map((resource) => resource.id), [
      'dua-2',
      'amal-1',
    ]);
    expect(action.resource?.id, 'dua-2');
    expect(action.linkedResources.first.usageNote, 'Read');
  });

  test('old single-resource action construction remains compatible', () {
    final action = PlanAction(
      id: 'a',
      carePlanId: 'p',
      type: 'dua',
      title: 'Dua',
      frequency: const ActionFrequency.daily(),
      startDate: DateTime(2026, 10, 16),
      sortOrder: 0,
      reviewStatus: ActionReviewStatus.approved,
      reminderEnabled: true,
      resource: const LinkedResource(
        id: 'legacy-id',
        title: 'Legacy',
        type: 'dua',
      ),
    );
    expect(action.linkedResources.single.id, 'legacy-id');
  });
}
