import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/selected_draft_review.dart';

AdminContentItem item({
  String id = 'draft-1',
  String type = 'article',
  String slug = 'srg2024-qur-awaiting-reference',
  String title = 'সূত্র যাচাই প্রয়োজন',
  String visibility = 'staff_only',
  String status = 'draft',
}) => AdminContentItem(
  id: id,
  title: title,
  type: type,
  slug: slug,
  visibility: visibility,
  status: status,
  verificationStatus: 'pending',
);

void main() {
  test(
    'unverified source drafts may be sent for human review, not published',
    () {
      expect(canBulkSubmitDraftForReview(item()), isTrue);
      expect(canBulkSubmitDraftForReview(item(type: 'quran')), isTrue);
      expect(canBulkSubmitDraftForReview(item(type: 'dua')), isTrue);
      expect(canBulkSubmitDraftForReview(item(type: 'audio')), isTrue);
      expect(canBulkSubmitDraftForReview(item(type: 'hadith')), isTrue);
    },
  );

  test('selection excludes private QA and non-draft resources', () {
    expect(
      canBulkSubmitDraftForReview(item(visibility: 'patient_only')),
      isFalse,
    );
    expect(
      canBulkSubmitDraftForReview(item(visibility: 'assigned_only')),
      isFalse,
    );
    expect(
      canBulkSubmitDraftForReview(item(slug: 'qa-test-internal')),
      isFalse,
    );
    expect(canBulkSubmitDraftForReview(item(title: 'QA TEST ONLY')), isFalse);
    expect(canBulkSubmitDraftForReview(item(status: 'review')), isFalse);
    expect(canBulkSubmitDraftForReview(item(status: 'published')), isFalse);
    expect(canBulkSubmitDraftForReview(item(status: 'archived')), isFalse);
  });

  test('batch review candidates retain only explicitly selected draft IDs', () {
    final input = [
      item(id: 'eligible'),
      item(id: 'qa', slug: 'qa-test-record'),
      item(id: 'private', visibility: 'patient_only'),
      item(id: 'published', status: 'published'),
    ];
    final candidates = bulkReviewCandidates(input);
    expect(candidates.map((e) => e.id).toList(), ['eligible']);
  });
}
