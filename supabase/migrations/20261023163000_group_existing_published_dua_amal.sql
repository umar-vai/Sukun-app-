-- Presentation-only categorization of existing publicly published owner-sourced
-- Dua/Amal resources into the seven existing leaves under three UI groups.
-- No scripture, text, sources, verification or publication statuses are changed.
-- No auth/patient/private data touched. Idempotent on a database with no
-- owner-imported Sukun 2024 resources (disposable CI stack).
DO $$
DECLARE
  mappings jsonb := jsonb_build_object(
    'srg2024-dua-001', 'dua-azkar-protection',
    'srg2024-dua-002', 'dua-azkar-protection',
    'srg2024-dua-003', 'dua-azkar-protection',
    'srg2024-dua-004', 'dua-azkar-distress',
    'srg2024-dua-005', 'dua-azkar-distress',
    'srg2024-dua-006', 'dua-azkar-distress',
    'srg2024-dua-007', 'dua-azkar-protection',
    'srg2024-dua-008', 'dua-azkar-protection',
    'srg2024-dua-009', 'dua-azkar-morning',
    'srg2024-dua-010', 'dua-azkar-evening',
    'srg2024-dua-011', 'dua-azkar-morning',
    'srg2024-dua-012', 'dua-azkar-evening',
    'srg2024-dua-013', 'dua-azkar-sleep',
    'srg2024-dua-014', 'dua-azkar-protection',
    'srg2024-dua-015', 'dua-azkar-distress',
    'srg2024-dua-016', 'dua-azkar-distress',
    'srg2024-dua-017', 'dua-azkar-protection',
    'srg2024-dua-018', 'dua-azkar-masnun',
    'srg2024-dua-019', 'dua-azkar-masnun',
    'srg2024-dua-020', 'dua-azkar-masnun',
    'srg2024-dua-021', 'dua-azkar-travel',
    'srg2024-dua-022', 'dua-azkar-masnun',
    'srg2024-dua-023', 'dua-azkar-distress',
    'srg2024-aml-001', 'dua-azkar-morning',
    'srg2024-aml-002', 'dua-azkar-evening',
    'srg2024-aml-003', 'dua-azkar-sleep',
    'srg2024-aml-004', 'dua-azkar-sleep',
    'srg2024-aml-005', 'dua-azkar-sleep',
    'srg2024-aml-006', 'dua-azkar-sleep',
    'srg2024-aml-007', 'dua-azkar-sleep',
    'srg2024-aml-008', 'dua-azkar-protection'
  );
  published_count integer;
  changed_count integer;
  mapping_count integer;
  categorized_count integer;
BEGIN
  SELECT count(*) INTO mapping_count FROM jsonb_each_text(mappings);
  IF mapping_count <> 31 THEN
    RAISE EXCEPTION 'Expected 31 unique owner-sourced categorization rules, found %', mapping_count;
  END IF;

  SELECT count(*) INTO published_count
  FROM public.content_items ci
  WHERE ci.status = 'published'
    AND ci.type IN ('dua', 'amal')
    AND (ci.slug LIKE 'srg2024-dua-%' OR ci.slug LIKE 'srg2024-aml-%');

  -- Disposable local CI databases do not include owner-provided content.
  IF published_count = 0 THEN
    RETURN;
  END IF;
  IF published_count <> 31 THEN
    RAISE EXCEPTION 'Production content set drift: expected 31 published Dua/Amal items, got %', published_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.content_items ci
    WHERE ci.status = 'published'
      AND ci.type IN ('dua', 'amal')
      AND (ci.slug LIKE 'srg2024-dua-%' OR ci.slug LIKE 'srg2024-aml-%')
      AND (ci.category_id IS NOT NULL OR NOT (mappings ? ci.slug))
  ) THEN
    RAISE EXCEPTION 'Existing category or unmapped published resource found; no changes made';
  END IF;

  IF (
    SELECT count(DISTINCT target.slug)
    FROM jsonb_each_text(mappings) as rule(item_slug, category_slug)
    JOIN public.content_categories target ON target.slug = rule.category_slug
  ) <> 7 THEN
    RAISE EXCEPTION 'Seven approved Dua/Azkar category slugs must exist before mapping';
  END IF;

  UPDATE public.content_items ci
  SET category_id = target.id
  FROM jsonb_each_text(mappings) AS rule(item_slug, category_slug)
  JOIN public.content_categories target ON target.slug = rule.category_slug
  WHERE ci.slug = rule.item_slug
    AND ci.category_id IS NULL
    AND ci.status = 'published'
    AND ci.type IN ('dua', 'amal');

  GET DIAGNOSTICS changed_count = ROW_COUNT;
  IF changed_count <> 31 THEN
    RAISE EXCEPTION 'Atomic mapping incomplete: % of 31, rolling back', changed_count;
  END IF;

  SELECT count(*) INTO categorized_count
  FROM public.content_items ci
  JOIN public.content_categories cc ON cc.id = ci.category_id
  WHERE ci.status = 'published'
    AND ci.type IN ('dua', 'amal')
    AND ci.slug IN (SELECT key FROM jsonb_each_text(mappings))
    AND cc.slug LIKE 'dua-azkar-%';
  IF categorized_count <> 31 THEN
    RAISE EXCEPTION 'Postcondition failed: categorized % of 31', categorized_count;
  END IF;
END;
$$;
