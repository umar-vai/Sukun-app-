import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/domain/private_resource_draft_batch.dart';

void main() {
  Map<String, dynamic> entry({
    String id = 'SRG2024-DUA-001',
    String kind = 'dua',
  }) => {
    'source_resource_id': id,
    'source_category': kind,
    'approved_for_patient': false,
    'needs_canonical_review': true,
    'needs_clinical_review': false,
    'input': {
      'type': kind == 'quran' ? 'article' : 'dua',
      'title': 'Synthetic Test Card',
      'titleBn': 'টেস্ট ড্রাফট',
      'slug': id.toLowerCase(),
      'visibility': 'staff_only',
      'status': 'draft',
      'requestId': '2f071c9b-b8d1-5d26-a8b4-329e73f4a33b',
      'summary': 'Synthetic only',
      'body': 'FAKE guide text — not scripture.',
      'arabicText': null,
      'referenceText': 'সেলফ রুকইয়াহ গাইড · synthetic source',
      'sourceType': 'human_provided_book',
      'sourceReference': 'সেলফ রুকইয়াহ গাইড · synthetic source',
      'sourceEdition': 'নভেম্বর 2024',
      'rightsNote': 'Sukun Life owner attested app-use rights',
    },
  };

  Map<String, dynamic> catalog([List<Map<String, dynamic>>? entries]) => {
    'schema': 'sukun.private_admin_draft_payload.v1',
    'source_sha256': PrivateResourceDraftBatch.sourceSha256,
    'copyright_permission': 'user_attested_for_sukun_life_app',
    'imported': false,
    'published': false,
    'entries': entries ?? [entry()],
  };

  PrivateResourceDraftBatch parse(Map<String, dynamic> value) =>
      PrivateResourceDraftBatch.parse(utf8.encode(jsonEncode(value)));

  test('valid source creates staff-only unapproved entries', () {
    final batch = parse(catalog());
    expect(batch.items, hasLength(1));
    final item = batch.items.single;
    expect(item.input.visibility, 'staff_only');
    expect(item.input.status, 'draft');
    expect(item.input.validate(), isNull);
  });

  test('unverified Quran snippets are accepted only as editorial article', () {
    final row = entry(id: 'SRG2024-QUR-001', kind: 'quran');
    final batch = parse(catalog([row]));
    expect(batch.items.single.input.type, 'article');
    (row['input'] as Map<String, dynamic>)['type'] = 'quran';
    expect(() => parse(catalog([row])), throwsFormatException);
  });

  test('fail closed on wrong source, stale rights or public state', () {
    final wrongHash = catalog()..['source_sha256'] = 'wrong';
    expect(() => parse(wrongHash), throwsFormatException);
    final wrongRights = catalog()..['copyright_permission'] = 'pending';
    expect(() => parse(wrongRights), throwsFormatException);
    final published = catalog()..['published'] = true;
    expect(() => parse(published), throwsFormatException);
    final patient = entry();
    (patient['input'] as Map<String, dynamic>)['visibility'] = 'public';
    expect(() => parse(catalog([patient])), throwsFormatException);
    final fakeApproved = entry()..['approved_for_patient'] = true;
    expect(() => parse(catalog([fakeApproved])), throwsFormatException);
  });

  test('rejects duplicate resource IDs before any API calls', () {
    expect(() => parse(catalog([entry(), entry()])), throwsFormatException);
  });

  test('staging endpoint must exactly match approved project', () {
    expect(
      PrivateResourceDraftBatch.mayImport(
        environment: 'staging',
        supabaseUrl: PrivateResourceDraftBatch.stagingSupabaseUrl,
      ),
      isTrue,
    );
    expect(
      PrivateResourceDraftBatch.mayImport(
        environment: 'staging',
        supabaseUrl: 'https://vydfafumxptanpkmtrpr.supabase.co',
      ),
      isFalse,
    );
    expect(
      PrivateResourceDraftBatch.mayImport(
        environment: 'production',
        supabaseUrl: PrivateResourceDraftBatch.stagingSupabaseUrl,
      ),
      isFalse,
    );
  });
}
