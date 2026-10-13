-- Staging-first reference reconciliation of 101 Sukun Life Qur'an/editorial items.
-- Quran source compared for METADATA ONLY, using the 6,236-verse Uthmani corpus
-- at nuqayah/quran-text GitHub blob fcc214311897921d08bbc56879b82aa38328a5f3.
-- IMPORTANT: Normalized script/partial-verse matching is not byte-perfect
-- canonical verification. Do NOT publish, change Arabic, or clear review state.
CREATE TABLE IF NOT EXISTS public.quran_reference_reconciliation_audit (
  content_item_id uuid NOT NULL REFERENCES public.content_items(id),
  audit_version text NOT NULL,
  matched_surah smallint,
  matched_ayah integer,
  matched_end_ayah integer,
  approximate_text_similarity numeric(6,4),
  partial_verse_excerpt boolean NOT NULL DEFAULT false,
  decision text NOT NULL,
  original_arabic_md5 text NOT NULL,
  comparison_source text NOT NULL,
  reference_checked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(content_item_id, audit_version)
);
ALTER TABLE public.quran_reference_reconciliation_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.quran_reference_reconciliation_audit FROM public, anon, authenticated;

DO $do$
DECLARE
  item_count integer;
  changed_count integer;
BEGIN
  SELECT count(*) INTO item_count FROM public.content_items
  WHERE slug LIKE 'srg2024-qur-%';
  IF item_count = 0 THEN
    RAISE NOTICE 'No Sukun 2024 Qur''an editorial records here; audit schema only.';
    RETURN;
  END IF;
  IF item_count <> 101 THEN
    RAISE EXCEPTION 'Unsafe Qur''an reconciliation: expected 101, got %',
      item_count;
  END IF;

  CREATE TEMP TABLE _sukun_quran_reference_matches (
    slug text PRIMARY KEY, expected_text_md5 text,
    surah smallint, ayah integer, last_ayah integer,
    similarity numeric(6,4), partial_excerpt boolean, decision text
  ) ON COMMIT DROP;

  INSERT INTO _sukun_quran_reference_matches VALUES
    ('srg2024-qur-001', 'e66ff7099280e3b12f647ff687bc5dd1', NULL, NULL, NULL, NULL, false, 'non_ayah_intro'),
    ('srg2024-qur-002', '6c1691b064f3287e95f0c93d0104b1d0', 1, 2, 7, 0.9836, false, 'normalized_match'),
    ('srg2024-qur-003', '3fb0418db21ae160ccaa24ce46507d21', 2, 1, 5, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-004', 'f188e74f7c98dac72da2621080760c71', 2, 163, 164, 0.9908, false, 'normalized_match'),
    ('srg2024-qur-005', '56adfc8165ed4f7b2e131e7dd411cc87', 2, 255, 255, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-006', '495d1d16ab9cd85a191d845a57237347', 2, 285, 286, 0.9968, false, 'normalized_match'),
    ('srg2024-qur-007', 'e736bde72f4bb86a693c6b58ecf9ced7', 3, 18, 18, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-008', '55ae5df7cc5aa4e73bba1a8f2945259d', 7, 54, 56, 0.9916, false, 'normalized_match'),
    ('srg2024-qur-009', '277bf7a96fb8dfceb2f079c5bd92e4ea', 59, 21, 24, 0.9831, false, 'normalized_match'),
    ('srg2024-qur-010', '67b4325452c19bf9a7efddd980b2070d', 72, 3, 3, 0.9688, false, 'normalized_match'),
    ('srg2024-qur-011', 'dca80a1059591616433e5199f4a76bfa', 112, 1, 4, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-012', '9f685a90e0155dd7878b201df6db8dcb', 113, 1, 5, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-013', 'e2f3795c32d3aab05710f7fd11498adb', 114, 1, 6, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-014', '5354752f97b50888e164547f2d8c02c9', 2, 30, 30, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-015', '3d129d5916b7bbe0c9ef4a039bc79cd9', 55, 33, 36, 0.9650, false, 'normalized_match'),
    ('srg2024-qur-016', 'a14eb715c996747f2696ab9e8e8a32a8', 6, 128, 128, 0.9932, false, 'normalized_match'),
    ('srg2024-qur-017', '0d3447dcbdf2d5efec8185daa87eab8a', 23, 115, 118, 0.9882, false, 'normalized_match'),
    ('srg2024-qur-018', 'de534534de2b1b5fdf347d6eb70127a3', 37, 1, 10, 0.9903, false, 'normalized_match'),
    ('srg2024-qur-019', 'c60e99e81973a4cd246e95489cd30c4b', 7, 179, 179, 0.9835, false, 'normalized_match'),
    ('srg2024-qur-020', '813e4c7b39cf8e075b60074862c23b2b', 2, 266, 266, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-021', 'adab110e08a5c4c0dcacc56381b93e5b', 3, 116, 116, 0.9730, false, 'normalized_match'),
    ('srg2024-qur-022', '26aea28bd43d5c8af156d0fadb2d94f0', 3, 181, 181, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-023', '1e1209263816fae8242703fe1dcf9952', 4, 56, 56, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-024', 'a5d8a611c023d750153e9f9e8dcb40bb', 5, 37, 37, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-025', 'a44dc4d2b15b6ac1e6d6bc27079106b5', 8, 50, 50, 0.9848, false, 'normalized_match'),
    ('srg2024-qur-026', 'bb63248d2862fe04c5853d612d41edd0', 14, 15, 18, 0.9950, false, 'normalized_match'),
    ('srg2024-qur-027', '5100a2f7335724040ee49664bb351e50', 14, 49, 50, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-028', 'a49dd594e821573b1da48709993c6ebf', 2, 7, 7, 0.9623, false, 'normalized_match'),
    ('srg2024-qur-029', '66647cff3d486d83f9c506a1ca3cbd87', 2, 20, 20, 0.9804, false, 'normalized_match'),
    ('srg2024-qur-030', 'ff957053dba7f65cd34ec741c83495d7', 2, 55, 55, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-031', '376a0af18fdb8e3d54266a7f0203a941', 2, 69, 69, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-032', 'a2eee2a1604f5019785c597050b147aa', 2, 109, 109, 0.9918, false, 'normalized_match'),
    ('srg2024-qur-033', '54bb0b12bf74d125a2973c8f7af94c8c', 2, 247, 247, 0.9939, false, 'normalized_match'),
    ('srg2024-qur-034', '43e8e57854f9ae2e29d36e6a0a751179', 2, 269, 269, 0.9848, false, 'normalized_match'),
    ('srg2024-qur-035', 'e78e1fe401bf63e86974af962671e18f', 7, 108, 108, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-036', '69ad05c7ec75974f0e47a22be8e4a1c1', 12, 67, 67, 0.9818, false, 'normalized_match'),
    ('srg2024-qur-037', '493224f223859028f8ae26f99bfad46f', 13, 5, 5, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-038', 'ce7463be24104d64d3697f018ac0fe39', 7, 117, 122, 0.9926, false, 'normalized_match'),
    ('srg2024-qur-039', '314a2126104357a83aa3a69187bf84a1', 10, 81, 81, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-040', '328fedc57a7e0a61bbc1a57a44866c58', 10, 82, 82, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-041', 'c03e186a365367d71fd3fcadc70f47d7', 20, 69, 69, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-042', '7941dc217f7488953547a13de7791b61', 25, 23, 23, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-043', '360976d9f71cd2aa03a1f2bef7899272', 17, 81, 81, 0.9444, false, 'normalized_match'),
    ('srg2024-qur-044', 'd804515277417a836d5551d776267083', 2, 102, 102, 0.9868, false, 'normalized_match'),
    ('srg2024-qur-045', 'd9c5425e3c5e3764f74bb0b90d1b9607', 3, 103, 103, 0.9872, false, 'normalized_match'),
    ('srg2024-qur-046', '2f1f24bb3ab0e708cf358fc241b5bbe7', 2, 165, 165, 0.9919, false, 'normalized_match'),
    ('srg2024-qur-047', '972663a0b82a4498edd58bb4cd3df68e', NULL, NULL, NULL, NULL, false, 'non_ayah_intro'),
    ('srg2024-qur-048', '982eabe05abdf39d9aa033602674ff5b', 19, 1, 9, 0.9936, false, 'normalized_match'),
    ('srg2024-qur-049', 'd746ec18678f77de2a7fb8fe8ddc1764', 9, 14, 14, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-050', 'fa0188803f22ced6eaf688783ddd85ca', 10, 57, 57, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-051', '0abbcbe44d1f995ae50f369cf2e03d5e', 16, 69, 69, 0.9744, true, 'normalized_match'),
    ('srg2024-qur-052', '14a174a3e9497c3769cb2759b096ddaa', 17, 82, 82, 0.9706, true, 'normalized_match'),
    ('srg2024-qur-053', '1175356a8cc5ae47173ffb1a0d2d06a2', 26, 80, 80, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-054', '63f5e9cd54ce3b9527eb67c924d178f2', 41, 44, 44, 0.9545, true, 'normalized_match'),
    ('srg2024-qur-055', '04cfea1b8c5317e265adad6b99479c09', 2, 161, 162, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-056', '5c4630832ea50c93965a6188c2673fe1', 2, 190, 193, 0.9890, false, 'normalized_match'),
    ('srg2024-qur-057', '8e03afedcd6aaa7e053434118d8415d3', 4, 76, 76, 0.9479, false, 'normalized_match'),
    ('srg2024-qur-058', '6969583fd37db31c54e104b148f06c66', 4, 78, 78, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-059', '5d8ad309d22ce11a65fb2e5371ae502a', 5, 33, 33, 0.9929, false, 'normalized_match'),
    ('srg2024-qur-060', 'd1e10e027253cc52054e0d1823d8dd28', 29, 57, 57, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-061', 'ed9c0286d05a576ca77d97b0fe37fc93', 2, 168, 169, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-062', 'd34d7ee9bf969369edec9d6a33eccc85', 2, 268, 268, 0.9851, false, 'normalized_match'),
    ('srg2024-qur-063', '9d05d29d1d50e2be50683bafa4c2c28b', 3, 14, 14, 0.9758, false, 'normalized_match'),
    ('srg2024-qur-064', '7e56d348d146e72d02109996f2a8c4c4', 3, 135, 135, 0.9904, false, 'normalized_match'),
    ('srg2024-qur-065', 'e94f51589fcadf1ea972270582079822', 7, 33, 33, 0.9908, false, 'normalized_match'),
    ('srg2024-qur-066', '4e1c51d09376757f590faa553758c1ef', 17, 32, 32, 0.9706, false, 'normalized_match'),
    ('srg2024-qur-067', '4a8a292f147166c21c13d5ce63b84f0b', 27, 54, 54, 0.9744, false, 'normalized_match'),
    ('srg2024-qur-068', '3951f5cb5e99ef7473323b097a6c3797', 29, 28, 28, 0.9821, false, 'normalized_match'),
    ('srg2024-qur-069', 'd41393ce31a2a2d0ec2245e19ad303c9', 2, 72, 72, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-070', 'b2bb61502cc39a09c52353e9c62c58ce', 2, 149, 149, 0.9848, false, 'normalized_match'),
    ('srg2024-qur-071', 'e6292f5596764e4443c42ba40d1a0260', 6, 95, 95, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-072', 'eb63ce493d9530291727b93860c36a6e', 7, 13, 13, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-073', '5016fdec3eff49d24daef99d0d8df2f0', 15, 34, 34, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-074', 'e4e22b45d7f1c550ddef68c6f9c613eb', 65, 2, 2, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-075', '10196970f9765ffc65db975549929a20', 71, 18, 18, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-076', 'de8c6151b97c5d5aab2ba3402b155f32', 84, 1, 5, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-077', '027ea44fa22c8d859fb0e443a821c71b', 99, 2, 2, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-078', 'e082ae61c03cdba8007f309e65b45b28', 36, 58, 58, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-079', '3e9d75a160126a6169e76e9d8fc7ee5a', 37, 79, 79, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-080', '205590f27aa5f42f9051ed196bbc0ab9', 37, 109, 109, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-081', 'f7e7a0db74217e5a85c5ec77d1e5bdc7', 37, 120, 120, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-082', '7a69f9eb09b505f76041773df6fb7b03', 37, 130, 130, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-083', 'a985ec320ecc15978830b5e5ebcd072d', 39, 73, 73, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-084', 'e15fa04eb0e8df94ea94618f063fe27a', 97, 5, 5, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-085', 'e884373251fc406b2622f3c8ab1aa682', 2, 248, 248, 0.9800, true, 'normalized_match'),
    ('srg2024-qur-086', '2d683cf3a5554b74baef697f3b3f14ba', 9, 26, 26, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-087', 'be76f6790b80af9922265351fcdee045', 9, 40, 40, 0.9844, true, 'normalized_match'),
    ('srg2024-qur-088', '5aa453aa8751d294021a6c45eddfe83f', 48, 4, 4, 0.9630, true, 'normalized_match'),
    ('srg2024-qur-089', 'c571aeb3fd970c6ac4e116300035f232', 48, 18, 18, 0.9884, false, 'normalized_match'),
    ('srg2024-qur-090', 'd07037f48f3ec786af84b43471cabedd', 48, 26, 26, 0.9868, true, 'normalized_match'),
    ('srg2024-qur-091', 'b677d2ab7521470bd2166e35cbdb4847', 2, 178, 178, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-092', 'dff00a6e78e5b515b2c0988406099a41', 8, 66, 66, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-093', '97d7d2d073d11937cd329729769cd530', 4, 28, 28, 0.9706, false, 'normalized_match'),
    ('srg2024-qur-094', '38a2ea7eaf0a67deb6a4f7af4e9bafef', 21, 69, 69, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-095', 'a633152468b07286e20468b3684a737f', 36, 78, 79, 0.9870, false, 'normalized_match'),
    ('srg2024-qur-096', 'eaec03c46a2a5f9094a75dd3115cbbc1', 23, 14, 14, 0.9798, false, 'normalized_match'),
    ('srg2024-qur-097', '02e74308f336a7c8dc87016509c10aed', 2, 259, 259, 1.0000, true, 'normalized_match'),
    ('srg2024-qur-098', '6bad03f709af820b24155d722835fdbd', 76, 28, 28, 0.9783, false, 'normalized_match'),
    ('srg2024-qur-099', '51b65bd02fc489183ba5b3f77eb12c20', 17, 49, 49, 0.8667, false, 'crosschecked_quran_com'),
    ('srg2024-qur-100', 'ae22b347716ec704cbcb6de4d83c69a3', 19, 4, 4, 1.0000, false, 'normalized_match'),
    ('srg2024-qur-101', 'a0cb00f58a30318f93a00e462c5df59a', 86, 7, 7, 1.0000, false, 'normalized_match');

  IF (SELECT count(*) FROM _sukun_quran_reference_matches) <> 101
     OR EXISTS (
       SELECT 1 FROM _sukun_quran_reference_matches v
       LEFT JOIN public.content_items ci ON ci.slug = v.slug
       WHERE ci.id IS NULL
          OR md5(ci.arabic_text) IS DISTINCT FROM v.expected_text_md5
          OR ci.surah_number IS DISTINCT FROM v.surah
          OR ci.ayah_number IS DISTINCT FROM v.ayah
     )
  THEN
    RAISE EXCEPTION 'Qur''an source rows changed since preflight; abort';
  END IF;

  -- Adjust reference metadata only. Original Arabic bytes, source edition,
  -- publication status, visibility, roles, and patient plans are untouched.
  UPDATE public.content_items ci
  SET
    ayah_end_number = CASE
      WHEN v.last_ayah > v.ayah THEN v.last_ayah
      ELSE NULL
    END,
    title = CASE
      WHEN v.slug = 'srg2024-qur-001' THEN
        'প্রাথমিক রুকইয়াহ — আউযুবিল্লাহ ও বিসমিল্লাহ (ভূমিকা; স্বতন্ত্র আয়াত নয়)'
      WHEN v.slug = 'srg2024-qur-047' THEN
        'জাদু ও বিশেষ আয়াত — বিসমিল্লাহ (ভূমিকা; স্বতন্ত্র আয়াত নয়)'
      ELSE replace(
        ci.title, '(সূত্র যাচাই প্রয়োজন)',
        '(রেফারেন্স মিলেছে; আরবি পাঠ পর্যালোচনাধীন)'
      )
    END,
    title_bn = CASE
      WHEN ci.title_bn IS NULL THEN NULL
      WHEN v.slug = 'srg2024-qur-001' THEN
        'প্রাথমিক রুকইয়াহ — আউযুবিল্লাহ ও বিসমিল্লাহ (ভূমিকা; স্বতন্ত্র আয়াত নয়)'
      WHEN v.slug = 'srg2024-qur-047' THEN
        'জাদু ও বিশেষ আয়াত — বিসমিল্লাহ (ভূমিকা; স্বতন্ত্র আয়াত নয়)'
      ELSE replace(ci.title_bn, '(সূত্র যাচাই প্রয়োজন)',
         '(রেফারেন্স মিলেছে; আরবি পাঠ পর্যালোচনাধীন)')
    END
  FROM _sukun_quran_reference_matches v
  WHERE ci.slug = v.slug
    AND ci.type = 'article'
    AND ci.status IN ('review','published');
  GET DIAGNOSTICS changed_count = ROW_COUNT;
  IF changed_count <> 101 THEN
    RAISE EXCEPTION 'Unsafe reconciliation: updated only % of 101', changed_count;
  END IF;

  INSERT INTO public.quran_reference_reconciliation_audit(
    content_item_id,audit_version,matched_surah,matched_ayah,
    matched_end_ayah,approximate_text_similarity,partial_verse_excerpt,
    decision,original_arabic_md5,comparison_source
  )
  SELECT ci.id,'2026-10-14-nuqayah-uthmani',v.surah,v.ayah,
     v.last_ayah,v.similarity,v.partial_excerpt,v.decision,
     v.expected_text_md5,
     'nuqayah/quran-text GitHub blob fcc214311897921d08bbc56879b82aa38328a5f3; Quran.com reference crosscheck where noted; comparison does NOT modify or certify Arabic edition'
  FROM _sukun_quran_reference_matches v
  JOIN public.content_items ci ON ci.slug = v.slug
  ON CONFLICT (content_item_id, audit_version)
  DO UPDATE SET matched_surah=excluded.matched_surah,
     matched_ayah=excluded.matched_ayah,
     matched_end_ayah=excluded.matched_end_ayah,
     approximate_text_similarity=excluded.approximate_text_similarity,
     partial_verse_excerpt=excluded.partial_verse_excerpt,
     decision=excluded.decision,
     original_arabic_md5=excluded.original_arabic_md5;

  RAISE NOTICE '101 metadata-only Quran editorial records reconciled. No publication, canonical verification, or Arabic replacement.';
END
$do$;
