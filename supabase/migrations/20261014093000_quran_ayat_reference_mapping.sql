-- Quran verse REFERENCE metadata only (not verified canonical Quran text).
-- Source: Quran.com reference pages, cross-checked with complete 6,236-verse
-- Hafs no-diacritic corpus (fawazahmed0/quran-api, King Fahad Quran Complex).
-- 99 source excerpts: do NOT modify Arabic, editorial title, rights, status or visibility.
-- ayah_end_number intentionally untouched for editorial article records.
-- 001 (Isti'adhah + Basmala) and 047 (isolated Basmala) deliberately excluded.
-- Rows are protected by original text MD5 so concurrent edits are not overwritten.
-- Review remains human-required; not a religious/publication verification.
with reviewed_reference(slug, surah, first_ayah, last_ayah, original_arabic_md5) as (
 values
  ('srg2024-qur-002', 1, 2, 7, '6c1691b064f3287e95f0c93d0104b1d0'),
  ('srg2024-qur-003', 2, 1, 5, '3fb0418db21ae160ccaa24ce46507d21'),
  ('srg2024-qur-004', 2, 163, 164, 'f188e74f7c98dac72da2621080760c71'),
  ('srg2024-qur-005', 2, 255, 255, '56adfc8165ed4f7b2e131e7dd411cc87'),
  ('srg2024-qur-006', 2, 285, 286, '495d1d16ab9cd85a191d845a57237347'),
  ('srg2024-qur-007', 3, 18, 18, 'e736bde72f4bb86a693c6b58ecf9ced7'),
  ('srg2024-qur-008', 7, 54, 56, '55ae5df7cc5aa4e73bba1a8f2945259d'),
  ('srg2024-qur-009', 59, 21, 24, '277bf7a96fb8dfceb2f079c5bd92e4ea'),
  ('srg2024-qur-010', 72, 3, 3, '67b4325452c19bf9a7efddd980b2070d'),
  ('srg2024-qur-011', 112, 1, 4, 'dca80a1059591616433e5199f4a76bfa'),
  ('srg2024-qur-012', 113, 1, 5, '9f685a90e0155dd7878b201df6db8dcb'),
  ('srg2024-qur-013', 114, 1, 6, 'e2f3795c32d3aab05710f7fd11498adb'),
  ('srg2024-qur-014', 2, 30, 30, '5354752f97b50888e164547f2d8c02c9'),
  ('srg2024-qur-015', 55, 33, 36, '3d129d5916b7bbe0c9ef4a039bc79cd9'),
  ('srg2024-qur-016', 6, 128, 128, 'a14eb715c996747f2696ab9e8e8a32a8'),
  ('srg2024-qur-017', 23, 115, 118, '0d3447dcbdf2d5efec8185daa87eab8a'),
  ('srg2024-qur-018', 37, 1, 10, 'de534534de2b1b5fdf347d6eb70127a3'),
  ('srg2024-qur-019', 7, 179, 179, 'c60e99e81973a4cd246e95489cd30c4b'),
  ('srg2024-qur-020', 2, 266, 266, '813e4c7b39cf8e075b60074862c23b2b'),
  ('srg2024-qur-021', 3, 116, 116, 'adab110e08a5c4c0dcacc56381b93e5b'),
  ('srg2024-qur-022', 3, 181, 181, '26aea28bd43d5c8af156d0fadb2d94f0'),
  ('srg2024-qur-023', 4, 56, 56, '1e1209263816fae8242703fe1dcf9952'),
  ('srg2024-qur-024', 5, 37, 37, 'a5d8a611c023d750153e9f9e8dcb40bb'),
  ('srg2024-qur-025', 8, 50, 50, 'a44dc4d2b15b6ac1e6d6bc27079106b5'),
  ('srg2024-qur-026', 14, 15, 18, 'bb63248d2862fe04c5853d612d41edd0'),
  ('srg2024-qur-027', 14, 49, 50, '5100a2f7335724040ee49664bb351e50'),
  ('srg2024-qur-028', 2, 7, 7, 'a49dd594e821573b1da48709993c6ebf'),
  ('srg2024-qur-029', 2, 20, 20, '66647cff3d486d83f9c506a1ca3cbd87'),
  ('srg2024-qur-030', 2, 55, 55, 'ff957053dba7f65cd34ec741c83495d7'),
  ('srg2024-qur-031', 2, 69, 69, '376a0af18fdb8e3d54266a7f0203a941'),
  ('srg2024-qur-032', 2, 109, 109, 'a2eee2a1604f5019785c597050b147aa'),
  ('srg2024-qur-033', 2, 247, 247, '54bb0b12bf74d125a2973c8f7af94c8c'),
  ('srg2024-qur-034', 2, 269, 269, '43e8e57854f9ae2e29d36e6a0a751179'),
  ('srg2024-qur-035', 7, 108, 108, 'e78e1fe401bf63e86974af962671e18f'),
  ('srg2024-qur-036', 12, 67, 67, '69ad05c7ec75974f0e47a22be8e4a1c1'),
  ('srg2024-qur-037', 13, 5, 5, '493224f223859028f8ae26f99bfad46f'),
  ('srg2024-qur-038', 7, 117, 122, 'ce7463be24104d64d3697f018ac0fe39'),
  ('srg2024-qur-039', 10, 81, 81, '314a2126104357a83aa3a69187bf84a1'),
  ('srg2024-qur-040', 10, 82, 82, '328fedc57a7e0a61bbc1a57a44866c58'),
  ('srg2024-qur-041', 20, 69, 69, 'c03e186a365367d71fd3fcadc70f47d7'),
  ('srg2024-qur-042', 25, 23, 23, '7941dc217f7488953547a13de7791b61'),
  ('srg2024-qur-043', 17, 81, 81, '360976d9f71cd2aa03a1f2bef7899272'),
  ('srg2024-qur-044', 2, 102, 102, 'd804515277417a836d5551d776267083'),
  ('srg2024-qur-045', 3, 103, 103, 'd9c5425e3c5e3764f74bb0b90d1b9607'),
  ('srg2024-qur-046', 2, 165, 165, '2f1f24bb3ab0e708cf358fc241b5bbe7'),
  ('srg2024-qur-048', 19, 1, 9, '982eabe05abdf39d9aa033602674ff5b'),
  ('srg2024-qur-049', 9, 14, 14, 'd746ec18678f77de2a7fb8fe8ddc1764'),
  ('srg2024-qur-050', 10, 57, 57, 'fa0188803f22ced6eaf688783ddd85ca'),
  ('srg2024-qur-051', 16, 69, 69, '0abbcbe44d1f995ae50f369cf2e03d5e'),
  ('srg2024-qur-052', 17, 82, 82, '14a174a3e9497c3769cb2759b096ddaa'),
  ('srg2024-qur-053', 26, 80, 80, '1175356a8cc5ae47173ffb1a0d2d06a2'),
  ('srg2024-qur-054', 41, 44, 44, '63f5e9cd54ce3b9527eb67c924d178f2'),
  ('srg2024-qur-055', 2, 161, 162, '04cfea1b8c5317e265adad6b99479c09'),
  ('srg2024-qur-056', 2, 190, 193, '5c4630832ea50c93965a6188c2673fe1'),
  ('srg2024-qur-057', 4, 76, 76, '8e03afedcd6aaa7e053434118d8415d3'),
  ('srg2024-qur-058', 4, 78, 78, '6969583fd37db31c54e104b148f06c66'),
  ('srg2024-qur-059', 5, 33, 33, '5d8ad309d22ce11a65fb2e5371ae502a'),
  ('srg2024-qur-060', 29, 57, 57, 'd1e10e027253cc52054e0d1823d8dd28'),
  ('srg2024-qur-061', 2, 168, 169, 'ed9c0286d05a576ca77d97b0fe37fc93'),
  ('srg2024-qur-062', 2, 268, 268, 'd34d7ee9bf969369edec9d6a33eccc85'),
  ('srg2024-qur-063', 3, 14, 14, '9d05d29d1d50e2be50683bafa4c2c28b'),
  ('srg2024-qur-064', 3, 135, 135, '7e56d348d146e72d02109996f2a8c4c4'),
  ('srg2024-qur-065', 7, 33, 33, 'e94f51589fcadf1ea972270582079822'),
  ('srg2024-qur-066', 17, 32, 32, '4e1c51d09376757f590faa553758c1ef'),
  ('srg2024-qur-067', 27, 54, 54, '4a8a292f147166c21c13d5ce63b84f0b'),
  ('srg2024-qur-068', 29, 28, 28, '3951f5cb5e99ef7473323b097a6c3797'),
  ('srg2024-qur-069', 2, 72, 72, 'd41393ce31a2a2d0ec2245e19ad303c9'),
  ('srg2024-qur-070', 2, 149, 149, 'b2bb61502cc39a09c52353e9c62c58ce'),
  ('srg2024-qur-071', 6, 95, 95, 'e6292f5596764e4443c42ba40d1a0260'),
  ('srg2024-qur-072', 7, 13, 13, 'eb63ce493d9530291727b93860c36a6e'),
  ('srg2024-qur-073', 15, 34, 34, '5016fdec3eff49d24daef99d0d8df2f0'),
  ('srg2024-qur-074', 65, 2, 2, 'e4e22b45d7f1c550ddef68c6f9c613eb'),
  ('srg2024-qur-075', 71, 18, 18, '10196970f9765ffc65db975549929a20'),
  ('srg2024-qur-076', 84, 1, 5, 'de8c6151b97c5d5aab2ba3402b155f32'),
  ('srg2024-qur-077', 99, 2, 2, '027ea44fa22c8d859fb0e443a821c71b'),
  ('srg2024-qur-078', 36, 58, 58, 'e082ae61c03cdba8007f309e65b45b28'),
  ('srg2024-qur-079', 37, 79, 79, '3e9d75a160126a6169e76e9d8fc7ee5a'),
  ('srg2024-qur-080', 37, 109, 109, '205590f27aa5f42f9051ed196bbc0ab9'),
  ('srg2024-qur-081', 37, 120, 120, 'f7e7a0db74217e5a85c5ec77d1e5bdc7'),
  ('srg2024-qur-082', 37, 130, 130, '7a69f9eb09b505f76041773df6fb7b03'),
  ('srg2024-qur-083', 39, 73, 73, 'a985ec320ecc15978830b5e5ebcd072d'),
  ('srg2024-qur-084', 97, 5, 5, 'e15fa04eb0e8df94ea94618f063fe27a'),
  ('srg2024-qur-085', 2, 248, 248, 'e884373251fc406b2622f3c8ab1aa682'),
  ('srg2024-qur-086', 9, 26, 26, '2d683cf3a5554b74baef697f3b3f14ba'),
  ('srg2024-qur-087', 9, 40, 40, 'be76f6790b80af9922265351fcdee045'),
  ('srg2024-qur-088', 48, 4, 4, '5aa453aa8751d294021a6c45eddfe83f'),
  ('srg2024-qur-089', 48, 18, 18, 'c571aeb3fd970c6ac4e116300035f232'),
  ('srg2024-qur-090', 48, 26, 26, 'd07037f48f3ec786af84b43471cabedd'),
  ('srg2024-qur-091', 2, 178, 178, 'b677d2ab7521470bd2166e35cbdb4847'),
  ('srg2024-qur-092', 8, 66, 66, 'dff00a6e78e5b515b2c0988406099a41'),
  ('srg2024-qur-093', 4, 28, 28, '97d7d2d073d11937cd329729769cd530'),
  ('srg2024-qur-094', 21, 69, 69, '38a2ea7eaf0a67deb6a4f7af4e9bafef'),
  ('srg2024-qur-095', 36, 78, 79, 'a633152468b07286e20468b3684a737f'),
  ('srg2024-qur-096', 23, 14, 14, 'eaec03c46a2a5f9094a75dd3115cbbc1'),
  ('srg2024-qur-097', 2, 259, 259, '02e74308f336a7c8dc87016509c10aed'),
  ('srg2024-qur-098', 76, 28, 28, '6bad03f709af820b24155d722835fdbd'),
  ('srg2024-qur-099', 17, 49, 49, '51b65bd02fc489183ba5b3f77eb12c20'),
  ('srg2024-qur-100', 19, 4, 4, 'ae22b347716ec704cbcb6de4d83c69a3'),
  ('srg2024-qur-101', 86, 7, 7, 'a0cb00f58a30318f93a00e462c5df59a')
)
update public.content_items as ci
set
  surah_number = r.surah,
  ayah_number = r.first_ayah,
  -- Article excerpts are NOT canonical quran records. Keep the strict
  -- content_items_ayah_range constraint: only type=quran may use
  -- ayah_end_number. Preserve the full editorial reference in reference_text.
  reference_text = coalesce(nullif(btrim(ci.reference_text), ''), ci.source_reference, '') ||
    ' | Quran.com ayah reference (editorial metadata; verification pending): ' ||
    r.surah::text || ':' || r.first_ayah::text ||
    case when r.last_ayah > r.first_ayah then '-' || r.last_ayah::text else '' end,
  source_url = coalesce(ci.source_url, 'https://quran.com/' || r.surah || '/' || r.first_ayah),
  verification_status = 'pending',
  updated_at = now()
from reviewed_reference as r
where ci.slug = r.slug
  and ci.type = 'article'
  and ci.visibility = 'staff_only'
  and ci.status in ('review', 'published')
  and ci.title like '%সূত্র যাচাই প্রয়োজন%'
  and ci.surah_number is null
  and ci.ayah_number is null
  and ci.ayah_end_number is null
  and coalesce(ci.reference_text, '') not like '%Quran.com ayah reference (editorial metadata;%'
  and md5(ci.arabic_text) = r.original_arabic_md5;
