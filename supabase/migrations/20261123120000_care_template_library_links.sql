-- Link the structured resource library to the care templates
-- (owner request, 2026-11-23).
--
-- The owner asked that every template carry as many related library items
-- as fit (the 90 daily dua, the grouped Ruqyah audio, the Ruqyah PDFs, the
-- Self-Ruqyah guide sections and Qur'an chapters), so they can review and
-- trim them later. A template links at most 16 items.
--
-- Rules, so the result is always safe to import:
--   * Only published items a patient may be linked to are kept
--     (public / patient_only / assigned_only, never staff_only). Older
--     dua, amal and Ruqyah audio that 20261123090000 hid as superseded
--     (assigned_only) are dropped in favour of the library versions.
--   * The curated library list comes first, then the template's current
--     links, so anything a Super Admin added by hand is kept while there is
--     room. The same recording under two slugs (an older audio that the
--     library moved into its group) is linked once.
--   * Nothing is inferred about dose, count or timing: links are reading
--     and listening material; the instruction text is not changed.
--   * Each changed template is written to admin_audit_logs with before and
--     after, and stays editable in the template editor.
--
-- Runs only where the library is installed (dua-ma-* or ruqyah-lib-*), so a
-- disposable CI database keeps its templates unchanged.

create or replace function private.curate_care_template_refs(
  p_candidates text[]
)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ref text;
  v_out text[] := '{}';
  v_seen text[] := '{}';
  v_id uuid;
  v_media text;
  v_key text;
begin
  foreach v_ref in array coalesce(p_candidates, '{}'::text[]) loop
    exit when cardinality(v_out) >= 16;
    if v_ref is null or v_ref = any(v_out) then
      continue;
    end if;
    if v_ref ~ '^quran:[0-9]{1,3}$' then
      if split_part(v_ref, ':', 2)::integer between 1 and 114 then
        v_out := array_append(v_out, v_ref);
      end if;
      continue;
    end if;
    select ci.id, nullif(btrim(coalesce(ci.media_url, '')), '')
      into v_id, v_media
    from public.content_items ci
    where ci.slug = v_ref
      and ci.status = 'published'
      and ci.visibility in ('public', 'patient_only', 'assigned_only')
      and not (
        ci.visibility = 'assigned_only'
        and ci.type in ('dua', 'amal', 'audio')
      )
    limit 1;
    if not found then
      continue;
    end if;
    v_key := coalesce(v_media, v_id::text);
    if v_key = any(v_seen) then
      continue;
    end if;
    v_seen := array_append(v_seen, v_key);
    v_out := array_append(v_out, v_ref);
  end loop;
  return v_out;
end;
$$;

revoke execute on function private.curate_care_template_refs(text[])
  from public, anon, authenticated;

create or replace function private.link_care_templates_to_library(
  p_actor uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
  v_before public.care_templates;
  v_refs text[];
  v_changed integer := 0;
begin
  for v_row in
    select c.template_id, c.candidates
    from (values
    ('a01', array['srg2024-c04-t033', 'dua-ma-01-01', 'dua-ma-01-02', 'dua-ma-01-03', 'dua-ma-01-04', 'dua-ma-01-05', 'dua-ma-02-01', 'dua-ma-03-01', 'dua-ma-03-02', 'dua-ma-04-01', 'dua-ma-16-01', 'dua-ma-16-02', 'dua-ma-16-03', 'ruqyah-lib-topic-09', 'sukun-ruqyahbd-ayatul-kursi', 'ruqyah-lib-topic-07', 'sukun-ruqyahbd-three-kul', 'pdf-ruqyah-15']::text[]),
    ('a02', array['srg2024-c04-t034', 'dua-ma-07-01', 'dua-ma-07-02', 'dua-ma-07-03', 'dua-ma-07-04', 'dua-ma-08-01', 'dua-ma-09-01', 'dua-ma-09-02', 'dua-ma-09-03', 'dua-ma-09-04', 'dua-ma-09-05', 'dua-ma-09-06', 'dua-ma-09-07', 'dua-ma-09-08', 'dua-ma-09-09', 'dua-ma-10-02']::text[]),
    ('a03', array['srg2024-c04-t036', 'dua-ma-13-01', 'dua-ma-13-02', 'dua-ma-13-06']::text[]),
    ('a04', array['dua-ma-09-01', 'dua-ma-17-04']::text[]),
    ('a05', array['dua-ma-01-02', 'dua-ma-02-01', 'srg2024-qur-005', 'quran:112', 'quran:113', 'quran:114', 'ruqyah-lib-topic-09', 'sukun-ruqyahbd-ayatul-kursi', 'ruqyah-lib-topic-07', 'sukun-ruqyahbd-three-kul', 'dua-ma-07-02', 'dua-ma-08-01']::text[]),
    ('a06', array['quran:2', 'ruqyah-lib-other-03', 'ruqyah-lib-special-05', 'sukun-ruqyahbd-baqara', 'dua-ma-03-01', 'dua-ma-07-03']::text[]),
    ('a07', array['ruqyah-lib-other-03', 'ruqyah-lib-special-05', 'sukun-ruqyahbd-baqara', 'quran:2', 'dua-ma-03-01', 'dua-ma-07-03']::text[]),
    ('a09', array['dua-ma-04-01', 'dua-ma-13-10']::text[]),
    ('a10', array['dua-ma-01-01', 'dua-ma-01-02', 'dua-ma-01-03', 'dua-ma-01-04', 'dua-ma-01-05', 'dua-ma-02-01', 'dua-ma-04-01']::text[]),
    ('a11', array['dua-ma-01-01', 'dua-ma-01-03', 'dua-ma-01-04', 'dua-ma-01-05', 'dua-ma-07-01', 'dua-ma-07-04', 'dua-ma-09-07', 'dua-ma-09-08']::text[]),
    ('b01', array['srg2024-ghs-002', 'srg2024-c03-t028', 'srg2024-c04-t014', 'pdf-ruqyah-04', 'ruqyah-lib-topic-01', 'sukun-ruqyahbd-evil-eye', 'ruqyah-lib-topic-02']::text[]),
    ('b02', array['srg2024-ghs-003', 'srg2024-c03-t029', 'srg2024-sup-007', 'srg2024-c04-t015', 'pdf-ruqyah-06', 'ruqyah-lib-topic-04', 'sukun-ruqyahbd-sihr-hibshi', 'ruqyah-lib-topic-03', 'ruqyah-lib-special-11', 'pdf-ruqyah-10']::text[]),
    ('b04', array['srg2024-ghs-002', 'srg2024-c03-t028', 'srg2024-c04-t014', 'pdf-ruqyah-04', 'ruqyah-lib-topic-01', 'sukun-ruqyahbd-evil-eye', 'ruqyah-lib-topic-02']::text[]),
    ('b05', array['srg2024-ghs-002', 'srg2024-ghs-003', 'srg2024-ghs-004', 'ruqyah-lib-topic-01', 'sukun-ruqyahbd-evil-eye', 'ruqyah-lib-topic-04', 'sukun-ruqyahbd-sihr-hibshi']::text[]),
    ('b06', array['srg2024-ghs-003', 'srg2024-ghs-004', 'srg2024-ghs-002', 'ruqyah-lib-topic-04', 'sukun-ruqyahbd-sihr-hibshi', 'ruqyah-lib-topic-01', 'sukun-ruqyahbd-evil-eye']::text[]),
    ('b07', array['ruqyah-lib-topic-01', 'sukun-ruqyahbd-evil-eye', 'ruqyah-lib-topic-02', 'srg2024-c04-t014', 'pdf-ruqyah-04', 'srg2024-ghs-002']::text[]),
    ('b08', array['ruqyah-lib-topic-04', 'sukun-ruqyahbd-sihr-hibshi', 'ruqyah-lib-topic-03', 'srg2024-c04-t015', 'pdf-ruqyah-06', 'srg2024-ghs-003']::text[]),
    ('s01', array['srg2024-c03-t004', 'srg2024-sup-001', 'quran:1', 'ruqyah-lib-other-04', 'sukun-ruqyahbd-fatiha', 'srg2024-qur-005', 'ruqyah-lib-topic-09', 'sukun-ruqyahbd-ayatul-kursi', 'quran:112', 'quran:113', 'quran:114', 'ruqyah-lib-topic-07', 'sukun-ruqyahbd-three-kul', 'srg2024-c04-t011', 'ruqyah-lib-short-02', 'sukun-ruqyahbd-common-bangla', 'pdf-ruqyah-01', 'pdf-ruqyah-03']::text[]),
    ('s02', array['srg2024-c03-t003', 'srg2024-c04-t015', 'pdf-ruqyah-06', 'ruqyah-lib-topic-03', 'ruqyah-lib-topic-04', 'sukun-ruqyahbd-sihr-hibshi', 'srg2024-c04-t021', 'pdf-ruqyah-08', 'ruqyah-lib-special-01', 'sukun-ruqyahbd-shifa', 'ruqyah-lib-other-06', 'sukun-ruqyahbd-shifa-sakina', 'srg2024-c04-t013', 'pdf-ruqyah-05', 'ruqyah-lib-topic-05', 'sukun-ruqyahbd-harq', 'srg2024-c04-t022', 'pdf-ruqyah-11', 'ruqyah-lib-special-10', 'sukun-ruqyahbd-qital-tadmir']::text[]),
    ('s03', array['pdf-ruqyah-01', 'pdf-ruqyah-03']::text[]),
    ('s04', array['pdf-ruqyah-01', 'pdf-ruqyah-03']::text[]),
    ('s10', array['pdf-ruqyah-01', 'pdf-ruqyah-03']::text[]),
    ('u01', array['ruqyah-lib-topic-06', 'sukun-ruqyahbd-jinn', 'srg2024-c04-t012', 'pdf-ruqyah-07', 'ruqyah-lib-hibshi-01', 'ruqyah-lib-hibshi-07', 'ruqyah-lib-hibshi-08']::text[]),
    ('u02', array['ruqyah-lib-topic-05', 'sukun-ruqyahbd-harq', 'ruqyah-lib-short-05', 'ruqyah-lib-short-06', 'srg2024-c04-t013', 'pdf-ruqyah-05']::text[]),
    ('u03', array['ruqyah-lib-special-10', 'sukun-ruqyahbd-qital-tadmir', 'srg2024-c04-t022', 'pdf-ruqyah-11', 'pdf-ruqyah-11-v1']::text[]),
    ('u04', array['ruqyah-lib-other-06', 'ruqyah-lib-other-06-v1', 'sukun-ruqyahbd-shifa-sakina', 'ruqyah-lib-special-01', 'ruqyah-lib-special-01-v1', 'sukun-ruqyahbd-shifa', 'ruqyah-lib-special-02', 'ruqyah-lib-special-02-v1', 'srg2024-c04-t021', 'srg2024-c04-t026', 'pdf-ruqyah-08', 'pdf-ruqyah-09']::text[]),
    ('u05', array['ruqyah-lib-other-07', 'ruqyah-lib-short-04', 'sukun-ruqyahbd-khuruj', 'srg2024-c04-t024', 'pdf-ruqyah-14']::text[]),
    ('u06', array['ruqyah-lib-topic-01', 'sukun-ruqyahbd-evil-eye', 'ruqyah-lib-topic-02', 'srg2024-c04-t014', 'pdf-ruqyah-04']::text[]),
    ('u07', array['ruqyah-lib-topic-04', 'sukun-ruqyahbd-sihr-hibshi', 'ruqyah-lib-topic-03', 'ruqyah-lib-topic-10', 'ruqyah-lib-special-11', 'srg2024-c04-t015', 'srg2024-c04-t016', 'pdf-ruqyah-06', 'pdf-ruqyah-10', 'pdf-ruqyah-10-v1']::text[]),
    ('u08', array['ruqyah-lib-topic-08', 'sukun-ruqyahbd-eight-surah']::text[]),
    ('u09', array['ruqyah-lib-topic-07', 'sukun-ruqyahbd-three-kul', 'quran:112', 'quran:113', 'quran:114', 'dua-ma-02-01', 'dua-ma-08-01']::text[]),
    ('u10', array['ruqyah-lib-topic-09', 'sukun-ruqyahbd-ayatul-kursi', 'srg2024-qur-005', 'dua-ma-01-02', 'dua-ma-07-02']::text[]),
    ('u11', array['ruqyah-lib-reciters-08', 'ruqyah-lib-short-01']::text[]),
    ('u12', array['ruqyah-lib-reciters-06', 'sukun-ruqyahbd-ajmy', 'quran:112', 'quran:113', 'quran:114', 'srg2024-qur-005']::text[]),
    ('u13', array['ruqyah-lib-short-02', 'ruqyah-lib-reciters-01', 'ruqyah-lib-reciters-02', 'ruqyah-lib-reciters-03', 'ruqyah-lib-reciters-04', 'ruqyah-lib-reciters-05', 'ruqyah-lib-reciters-06', 'ruqyah-lib-reciters-07', 'ruqyah-lib-reciters-08', 'ruqyah-lib-reciters-09', 'ruqyah-lib-reciters-10', 'ruqyah-lib-reciters-11', 'ruqyah-lib-reciters-12', 'ruqyah-lib-more-reciters-01', 'ruqyah-lib-more-reciters-02', 'ruqyah-lib-more-reciters-03', 'ruqyah-lib-more-reciters-04', 'ruqyah-lib-more-reciters-05', 'ruqyah-lib-more-reciters-06', 'ruqyah-lib-more-reciters-07', 'ruqyah-lib-more-reciters-08']::text[]),
    ('x01', array['quran:60', 'quran:28', 'quran:25', 'dua-ma-13-09']::text[]),
    ('x03', array['srg2024-c02-t005', 'srg2024-c04-t008', 'dua-ma-02-01', 'dua-ma-01-02']::text[]),
    ('x04', array['dua-ma-13-08', 'dua-ma-13-09', 'ruqyah-lib-hibshi-02']::text[]),
    ('x05', array['ruqyah-lib-other-01', 'pdf-ruqyah-02', 'pdf-ruqyah-03']::text[]),
    ('x06', array['pdf-ruqyah-01', 'pdf-ruqyah-03']::text[])
    ) as c(template_id, candidates)
    order by c.template_id
  loop
    select ct.* into v_before
    from public.care_templates ct
    where ct.id = v_row.template_id
    for update;
    if not found then
      continue;
    end if;
    v_refs := private.curate_care_template_refs(
      v_row.candidates || v_before.resource_refs
    );
    if v_refs = v_before.resource_refs then
      continue;
    end if;
    update public.care_templates
    set resource_refs = v_refs,
        updated_at = now(),
        updated_by = coalesce(p_actor, updated_by)
    where id = v_row.template_id;
    insert into public.admin_audit_logs (
      actor_user_id, action, entity_type, entity_id, metadata
    ) values (
      p_actor,
      'care_template.library_links_curated',
      'care_template',
      null,
      jsonb_build_object(
        'template_id', v_row.template_id,
        'before', v_before.resource_refs,
        'after', v_refs,
        'reason', 'owner request 2026-11-23: link related library items'
      )
    );
    v_changed := v_changed + 1;
  end loop;
  return v_changed;
end;
$$;

revoke execute on function private.link_care_templates_to_library(uuid)
  from public, anon, authenticated;

do $$
declare
  v_actor uuid;
  v_changed integer;
begin
  if not exists (
    select 1 from public.content_items
    where status = 'published'
      and (slug like 'dua-ma-%' or slug like 'ruqyah-lib-%')
  ) then
    raise notice 'Resource library not installed; templates unchanged.';
    return;
  end if;

  select ur.user_id into v_actor
  from public.user_roles ur
  join auth.users u on u.id = ur.user_id
  where ur.role = 'super_admin'
  order by u.created_at, ur.user_id
  limit 1;

  v_changed := private.link_care_templates_to_library(v_actor);
  raise notice 'Care templates linked to the library: %', v_changed;
end;
$$;
