import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/selected_review_actions.dart';

AdminContentItem reviewItem({
  String id = 'review-1',
  String slug = 'srg2024-qur-ayat-requires-source',
  String status = 'review',
  String visibility = 'staff_only',
  String type = 'article',
  String title = 'সূত্র যাচাই প্রয়োজন',
}) => AdminContentItem(
  id: id,
  type: type,
  title: title,
  slug: slug,
  status: status,
  visibility: visibility,
  verificationStatus: 'not_required',
);

void main() {
  test('unsourced Quran editorial articles can return to draft for correction', () {
    expect(canManageSelectedReview(reviewItem()), isTrue);
    expect(canManageSelectedReview(reviewItem(type: 'quran')), isTrue);
    expect(canManageSelectedReview(reviewItem(type: 'dua')), isTrue);
  });

  test('protected patient and QA records are never bulk edited', () {
    expect(
      canManageSelectedReview(reviewItem(visibility: 'patient_only')),
      isFalse,
    );
    expect(
      canManageSelectedReview(reviewItem(visibility: 'assigned_only')),
      isFalse,
    );
    expect(canManageSelectedReview(reviewItem(slug: 'qa-test-only')), isFalse);
    expect(canManageSelectedReview(reviewItem(title: 'QA TEST ONLY')), isFalse);
  });

  test('published, draft, archived and verified content cannot be selected', () {
    for (final status in ['published', 'draft', 'archived', 'verified']) {
      expect(canManageSelectedReview(reviewItem(status: status)), isFalse);
    }
  });

  test('batch selection includes only eligible review records', () {
    final selected = selectedReviewCandidates([
      reviewItem(id: 'eligible'),
      reviewItem(id: 'published', status: 'published'),
      reviewItem(id: 'qa', slug: 'qa-fixture-review'),
    ]);
    expect(selected.map((item) => item.id).toList(), ['eligible']);
  });
}
