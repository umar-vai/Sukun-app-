import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_resource_prefill.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

void main() {
  test('published public library resource prefills editable Bangla titles', () {
    const resource = ContentResource(
      id: 'synthetic-audio',
      title: 'Ruqyah audio',
      titleBn: 'রুকইয়াহ অডিও',
      type: 'audio',
      visibility: 'public',
      status: 'published',
    );
    final prefill = PersonalRoutineResourcePrefill.fromResource(resource);
    expect(prefill?.contentId, 'synthetic-audio');
    expect(prefill?.actionTitle, 'রুকইয়াহ অডিও');
    expect(prefill?.notificationTitle, 'আজকের করণীয়: রুকইয়াহ অডিও');
  });

  test('staff-only or draft CMS items cannot prefill personal routines', () {
    const staff = ContentResource(
      id: 'staff',
      title: 'Hidden record',
      type: 'audio',
      visibility: 'staff_only',
      status: 'published',
    );
    const draft = ContentResource(
      id: 'draft',
      title: 'Draft',
      type: 'article',
      visibility: 'public',
      status: 'draft',
    );
    expect(PersonalRoutineResourcePrefill.fromResource(staff), isNull);
    expect(PersonalRoutineResourcePrefill.fromResource(draft), isNull);
    expect(PersonalRoutineResourcePrefill.fromResource(null), isNull);
  });

  test('English title is used when no Bengali title is published', () {
    const resource = ContentResource(
      id: 'synthetic-article',
      title: 'Morning reflection',
      titleBn: ' ',
      type: 'article',
      visibility: 'public',
      status: 'published',
    );
    expect(
      PersonalRoutineResourcePrefill.fromResource(resource)?.actionTitle,
      'Morning reflection',
    );
  });
}
