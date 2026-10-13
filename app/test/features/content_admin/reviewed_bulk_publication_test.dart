import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/reviewed_bulk_publication.dart';

AdminContentItem resource({
  String slug = 'srg2024-dua-001',
  String type = 'dua',
  String visibility = 'staff_only',
  String title = 'Reviewed material',
  String status = 'draft',
  String? rights = 'Owner approved',
  String? source = 'Book source',
}) => AdminContentItem(
  id: 'item',
  title: title,
  type: type,
  slug: slug,
  visibility: visibility,
  status: status,
  verificationStatus: 'not_required',
  sourceReference: source,
  rightsNote: rights,
);

void main() {
  test('eligible only for known, reviewed, noncanonical content', () {
    expect(canBulkPublishReviewedResource(resource()), isTrue);
    expect(
      canBulkPublishReviewedResource(
        resource(slug: 'srg2024-qur-001', title: 'সূত্র যাচাই প্রয়োজন'),
      ),
      isFalse,
    );
    expect(
      canBulkPublishReviewedResource(resource(visibility: 'patient_only')),
      isFalse,
    );
    expect(
      canBulkPublishReviewedResource(resource(slug: 'test-only-resource')),
      isFalse,
    );
    expect(canBulkPublishReviewedResource(resource(type: 'quran')), isFalse);
    expect(canBulkPublishReviewedResource(resource(rights: null)), isFalse);
    expect(canBulkPublishReviewedResource(resource(source: null)), isFalse);
    expect(
      canBulkPublishReviewedResource(resource(status: 'published')),
      isFalse,
    );
  });
}
