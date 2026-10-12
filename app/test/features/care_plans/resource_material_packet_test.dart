import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/resource_material_packet.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

void main() {
  const published = ContentResource(
    id: 'catalog-verified-1',
    type: 'dua',
    title: 'Verified Dua',
    titleBn: 'যাচাইকৃত দোয়া',
    visibility: 'patient_only',
    status: 'published',
    arabicText: 'SYNTHETIC ARABIC PLACEHOLDER',
    banglaText: 'Synthetic Bengali placeholder',
    referenceText: 'Approved source test',
  );
  const staffOnly = ContentResource(
    id: 'private-1',
    type: 'dua',
    title: 'PRIVATE TEXT',
    visibility: 'staff_only',
    status: 'draft',
    arabicText: 'PRIVATE SOURCE MUST NOT LEAK',
  );

  test('generates a reviewable handout from published resource only', () {
    final result = ResourceMaterialPacket.draftMarkdown([
      const MaterialPacketAction(
        title: 'Prescription instruction',
        instruction: 'TEST ONLY, human-authored',
        countTarget: 3,
        resource: published,
      ),
    ]);
    expect(result, contains('শুধু অ্যাডমিন পর্যালোচনার জন্য'));
    expect(result, contains('TEST ONLY, human-authored'));
    expect(result, contains('যাচাইকৃত দোয়া'));
    expect(result, contains('SYNTHETIC ARABIC PLACEHOLDER'));
    expect(result, contains('Approved source test'));
    expect(result, contains('সংখ্যা:** 3'));
  });

  test('unpublished staff-only text never enters material drafts', () {
    final result = ResourceMaterialPacket.draftMarkdown([
      const MaterialPacketAction(title: 'Needs review', resource: staffOnly),
    ]);
    expect(result, contains('Resource Library linkage'));
    expect(result, isNot(contains('PRIVATE SOURCE MUST NOT LEAK')));
  });

  test('unverified Quran is never exported as canonical text', () {
    const quran = ContentResource(
      id: 'quran-unverified',
      type: 'quran',
      title: 'Pending review',
      visibility: 'public',
      status: 'published',
      verificationStatus: 'pending',
      arabicText: 'UNVERIFIED ARABIC',
    );
    final result = ResourceMaterialPacket.draftMarkdown([
      const MaterialPacketAction(title: 'Read', resource: quran),
    ]);
    expect(result, isNot(contains('UNVERIFIED ARABIC')));
    expect(result, contains('উৎস পাওয়া যায়নি'));
  });

  test('never invents frequencies when prescription omits them', () {
    final result = ResourceMaterialPacket.draftMarkdown([
      const MaterialPacketAction(title: 'Unspecified schedule'),
    ]);
    expect(result, isNot(contains('সংখ্যা:**')));
    expect(result, isNot(contains('মিনিট')));
  });

  test('refuses empty draft', () {
    expect(
      () => ResourceMaterialPacket.draftMarkdown([]),
      throwsArgumentError,
    );
  });
}
