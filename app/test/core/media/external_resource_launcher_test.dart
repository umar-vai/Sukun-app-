import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/media/external_resource_launcher.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

void main() {
  test('builds an official YouTube watch URL from a video id', () {
    const resource = LinkedResource(
      id: 'resource-1',
      title: 'Ruqyah video',
      type: 'video',
      mediaSourceType: 'youtube',
      youtubeVideoId: 'abc_DEF-123',
    );

    expect(
      externalResourceUri(resource).toString(),
      'https://www.youtube.com/watch?v=abc_DEF-123',
    );
  });

  test('accepts HTTPS external media and rejects unsafe URLs', () {
    const safe = LinkedResource(
      id: 'resource-1',
      title: 'Guide',
      type: 'pdf',
      mediaSourceType: 'external_pdf',
      mediaUrl: 'https://cdn.example.com/guide.pdf',
    );
    const unsafe = LinkedResource(
      id: 'resource-2',
      title: 'Unsafe guide',
      type: 'pdf',
      mediaSourceType: 'external_pdf',
      mediaUrl: 'http://cdn.example.com/guide.pdf',
    );

    expect(externalResourceUri(safe), Uri.parse(safe.mediaUrl!));
    expect(externalResourceUri(unsafe), isNull);
  });
}
