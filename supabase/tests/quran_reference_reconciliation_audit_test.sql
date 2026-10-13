begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select has_table(
  'public',
  'quran_reference_reconciliation_audit',
  'reconciliation has a separate provenance/audit table'
);
select has_column(
  'public',
  'quran_reference_reconciliation_audit',
  'original_arabic_md5',
  'preflight tracks the exact original Arabic text'
);
select has_column(
  'public',
  'quran_reference_reconciliation_audit',
  'partial_verse_excerpt',
  'partial ayahs are identified without inventing a full verse'
);
select ok(
  not has_table_privilege('anon',
    'public.quran_reference_reconciliation_audit','SELECT'),
  'anonymous users cannot enumerate reconciliation audit records'
);
select ok(
  not has_table_privilege('authenticated',
    'public.quran_reference_reconciliation_audit','UPDATE'),
  'ordinary signed-in users cannot tamper with editorial audit evidence'
);
select results_eq(
  $$select count(*)::bigint from public.quran_reference_reconciliation_audit
    where audit_version='2026-10-14-nuqayah-uthmani'$$,
  array[0::bigint],
  'clean disposable test DB does not auto-import staging editorial content'
);

select * from finish();
rollback;
