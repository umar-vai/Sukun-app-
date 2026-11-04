import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_notification_destination.dart';

const resourceId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  test('verified published CMS media opens the actual in-app resource', () {
    expect(
      personalNotificationDestination([
        {
          'provider': 'cms',
          'content_item_id': resourceId,
          'content_items': {
            'id': resourceId,
            'status': 'published',
            'visibility': 'public',
            'type': 'audio',
          },
        },
      ]),
      '/resources/$resourceId',
    );
  });

  test('Quran reference opens corresponding surah/ayah reader', () {
    expect(
      personalNotificationDestination([
        {'provider': 'quran', 'external_resource_ref': 'quran:2:255'},
      ]),
      '/resources/quran/2?ayah=255',
    );
  });

  test('passive reminder opens checklist, never invents a resource route', () {
    expect(personalNotificationDestination(const []), '/my-routines?tab=today');
    expect(
      personalNotificationDestination([
        {'provider': 'cms', 'content_item_id': resourceId,
          'content_items': {'id': resourceId, 'status': 'draft',
            'visibility': 'public'}},
        {'provider': 'quran', 'external_resource_ref': 'quran:999'},
        {'provider': 'cms', 'content_item_id': 'https://attacker.example',
          'content_items': {'status': 'published', 'visibility': 'public'}},
      ]),
      '/my-routines?tab=today',
    );
  });
}
