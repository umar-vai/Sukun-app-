import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/video_navigation.dart';

void main() {
  test('valid YouTube video opens player in one tap', () {
    const video = ContentResource(
      id: 'video-1',
      title: 'Sample video',
      type: 'video',
      mediaSourceType: 'youtube',
      youtubeVideoId: 'abcdefghijk',
      visibility: 'public',
      status: 'published',
    );
    expect(opensYoutubePlayerDirectly(video), isTrue);
  });

  test('invalid YouTube ids do not try to open the player', () {
    const invalid = ContentResource(
      id: 'video-2',
      title: 'No video',
      type: 'video',
      mediaSourceType: 'youtube',
      youtubeVideoId: 'not a valid id',
      visibility: 'public',
      status: 'published',
    );
    expect(opensYoutubePlayerDirectly(invalid), isFalse);
  });

  test('nonvideo resources still open their own details', () {
    const article = ContentResource(
      id: 'article-1',
      title: 'Article with a video',
      type: 'article',
      mediaSourceType: 'youtube',
      youtubeVideoId: 'abcdefghijk',
      visibility: 'public',
      status: 'published',
    );
    expect(opensYoutubePlayerDirectly(article), isFalse);
  });

  test('direct media URLs are not mistaken for YouTube', () {
    const direct = ContentResource(
      id: 'video-3',
      title: 'Licensed direct video',
      type: 'video',
      mediaSourceType: 'direct_video_url',
      mediaUrl: 'https://example.org/video.mp4',
      visibility: 'public',
      status: 'published',
    );
    expect(opensYoutubePlayerDirectly(direct), isFalse);
  });
}
