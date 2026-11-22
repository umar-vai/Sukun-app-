-- Every fixture rolls back. Care templates gain related library items:
-- curated library links first, then the template's own links, only
-- published patient-linkable items, at most 16, the same recording once,
-- superseded (hidden) dua/audio dropped, every change audited.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000007901', 'links-admin@sukun.test', '{}')
on conflict do nothing;
insert into public.user_roles (user_id, role, granted_by) values
  ('00000000-0000-4000-8000-000000007901', 'super_admin',
   '00000000-0000-4000-8000-000000007901')
on conflict do nothing;

select private.install_resource_library('00000000-0000-4000-8000-000000007901');

-- An older dua that the retirement migration hid as superseded, and a
-- staff-only item: neither may stay linked.
insert into public.content_items (
  id, type, title, slug, visibility, status, published_at, created_by,
  updated_by
) values
  ('00000000-0000-4000-8000-000000007911', 'dua', 'Hidden old dua',
   'links-test-hidden-dua', 'assigned_only', 'published', now(),
   '00000000-0000-4000-8000-000000007901',
   '00000000-0000-4000-8000-000000007901'),
  ('00000000-0000-4000-8000-000000007912', 'article', 'Staff note',
   'links-test-staff-note', 'staff_only', 'published', now(),
   '00000000-0000-4000-8000-000000007901',
   '00000000-0000-4000-8000-000000007901'),
  ('00000000-0000-4000-8000-000000007913', 'article', 'Hand-picked guide',
   'links-test-hand-picked', 'public', 'published', now(),
   '00000000-0000-4000-8000-000000007901',
   '00000000-0000-4000-8000-000000007901');

create temporary table links_before on commit drop as
select id, instruction from public.care_templates;

update public.care_templates
set resource_refs = array[
  'links-test-hidden-dua', 'links-test-staff-note', 'links-test-hand-picked'
]
where id = 'a03';

select ok(
  private.link_care_templates_to_library(
    '00000000-0000-4000-8000-000000007901'
  ) > 30,
  'most templates gain library links'
);

create temporary table links_changed on commit drop as
select metadata->>'template_id' as id
from public.admin_audit_logs
where action = 'care_template.library_links_curated';

select ok(
  (select resource_refs from public.care_templates where id = 'a01')
    @> array['dua-ma-01-01', 'dua-ma-02-01', 'dua-ma-04-01'],
  'morning-evening amal links the morning-evening dua'
);
select ok(
  (select resource_refs from public.care_templates where id = 'a02')
    @> array['dua-ma-07-01', 'dua-ma-08-01', 'dua-ma-09-09'],
  'before-sleep amal links the sleep dua'
);
select ok(
  (select resource_refs from public.care_templates where id = 'u06')
    @> array['ruqyah-lib-topic-01', 'pdf-ruqyah-04'],
  'evil eye audio links the evil eye audio and its ayat PDF'
);
select ok(
  (select resource_refs from public.care_templates where id = 'u04')
    @> array['ruqyah-lib-special-01', 'pdf-ruqyah-08', 'pdf-ruqyah-09'],
  'shifa-sakina audio links shifa and sakina audio and PDFs'
);
select ok(
  (select resource_refs from public.care_templates where id = 'x01')
    @> array['quran:60', 'quran:28', 'quran:25', 'dua-ma-13-09'],
  'Qur''an chapter links are kept alongside the new dua'
);

select is(
  (select max(cardinality(resource_refs)) from public.care_templates) <= 16,
  true,
  'no template exceeds 16 links'
);
select is(
  (
    select count(*)::integer
    from public.care_templates ct, unnest(ct.resource_refs) r
    where r !~ '^quran:'
      and ct.id in (select id from links_changed)
      and not exists (
        select 1 from public.content_items ci
        where ci.slug = r and ci.status = 'published'
          and ci.visibility in ('public', 'patient_only', 'assigned_only')
      )
  ),
  0,
  'every slug linked by the curation is a published, patient-linkable item'
);

select ok(
  not ((select resource_refs from public.care_templates where id = 'a03')
    && array['links-test-hidden-dua', 'links-test-staff-note']),
  'hidden superseded and staff-only items are dropped'
);
select ok(
  (select resource_refs from public.care_templates where id = 'a03')
    @> array['links-test-hand-picked', 'dua-ma-13-01'],
  'hand-picked links are kept after the curated ones'
);

select is(
  (
    select count(*)::integer from public.care_templates ct
    where ct.id in (select id from links_changed)
      and (
      select count(distinct coalesce(nullif(ci.media_url, ''), ci.id::text))
      from unnest(ct.resource_refs) r
      join public.content_items ci on ci.slug = r
    ) <> (
      select count(*) from unnest(ct.resource_refs) r where r !~ '^quran:'
    )
  ),
  0,
  'the same recording is never linked twice'
);

select is(
  (
    select count(*)::integer from public.care_templates ct
    join links_before b on b.id = ct.id
    where ct.instruction is distinct from b.instruction
  ),
  0,
  'instruction text is not changed'
);

select ok(
  (
    select count(*) from public.admin_audit_logs
    where action = 'care_template.library_links_curated'
  ) > 30,
  'each change is audited'
);

select is(
  private.link_care_templates_to_library(
    '00000000-0000-4000-8000-000000007901'
  ),
  0,
  'a second run changes nothing'
);

select * from finish();
rollback;
