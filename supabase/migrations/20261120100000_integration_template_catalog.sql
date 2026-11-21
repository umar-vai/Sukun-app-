-- CRM/ERP integration: versioned export of the official Sukun care templates.
--
-- PURPOSE
--   The SukunLife catalog (`public.care_templates`) stays the single master.
--   This read-only function returns a deterministic, versioned JSON document
--   that the CRM mirrors. It is callable ONLY by the service role (the
--   `integration-templates` Edge Function, after verifying the CRM request);
--   `anon` and `authenticated` cannot execute it.
--
-- SAFETY
--   * No table, policy or data change. Pure read function.
--   * Exposes template content only: no patient data, no staff notes, no
--     timestamps inside the revision hash (so a revision changes only when
--     content changes).
--   * Hidden templates are returned with `active: false` (never silently
--     dropped) so the CRM can mirror deactivation without deleting history.
--
-- ROLLBACK
--   drop function public.integration_export_template_catalog(timestamptz, text, integer);

create or replace function public.integration_export_template_catalog(
  p_updated_since timestamptz default null,
  p_after_id text default null,
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  page_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
  catalog_hash text;
  total_count integer;
  last_updated timestamptz;
  items jsonb;
  returned_count integer;
  next_cursor text;
begin
  -- Content hash over every template (active or hidden) in a fixed order.
  select
    encode(sha256(convert_to(coalesce(string_agg(
      jsonb_build_array(
        t.id, t.category, t.action_type, t.title, t.instruction,
        t.notification_title, t.default_times::text[], t.resource_refs,
        t.requires_resource, t.sort_order, t.is_active
      )::text, '|' order by t.id), ''), 'UTF8')), 'hex'),
    count(*)::integer,
    max(t.updated_at)
  into catalog_hash, total_count, last_updated
  from public.care_templates t;

  select coalesce(jsonb_agg(x.obj order by x.id), '[]'::jsonb), count(*)::integer
  into items, returned_count
  from (
    select
      t.id,
      jsonb_build_object(
        'template_id', t.id,
        'template_revision', 'sha256:' || encode(sha256(convert_to(
          jsonb_build_array(
            t.id, t.category, t.action_type, t.title, t.instruction,
            t.notification_title, t.default_times::text[], t.resource_refs,
            t.requires_resource, t.sort_order, t.is_active
          )::text, 'UTF8')), 'hex'),
        'category', t.category,
        'action_type', t.action_type,
        'title', t.title,
        'instruction', t.instruction,
        'notification_title', t.notification_title,
        'parameters', (
          -- Placeholders are read mechanically from the instruction text.
          select coalesce(jsonb_agg(jsonb_build_object(
            'name', ph.name,
            'placeholder', ph.token,
            'type', 'integer',
            'required', true
          ) order by ph.ord), '[]'::jsonb)
          from (values
            (1, 'count',   '{বার}'),
            (2, 'days',    '{দিন}'),
            (3, 'minutes', '{মিনিট}')
          ) ph(ord, name, token)
          where position(ph.token in t.instruction) > 0
        ),
        'default_schedule', jsonb_build_object(
          'reminder_times', (
            select coalesce(jsonb_agg(to_char(dt, 'HH24:MI') order by ord), '[]'::jsonb)
            from unnest(t.default_times) with ordinality d(dt, ord)
          ),
          'time_basis', 'patient_local'
        ),
        'resource_refs', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'ref', r.ref,
            'kind', case when r.ref ~ '^quran:[0-9]+$' then 'quran_surah' else 'content_slug' end
          ) order by r.ord), '[]'::jsonb)
          from unnest(t.resource_refs) with ordinality r(ref, ord)
        ),
        'requires_resource', t.requires_resource,
        'sort_order', t.sort_order,
        'active', t.is_active,
        'updated_at', to_char(t.updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
      ) as obj
    from public.care_templates t
    where (p_updated_since is null or t.updated_at > p_updated_since)
      and (p_after_id is null or t.id > p_after_id)
    order by t.id
    limit page_limit
  ) x;

  if returned_count = page_limit then
    next_cursor := items -> (returned_count - 1) ->> 'template_id';
  end if;

  return jsonb_build_object(
    'schema_version', '1.0',
    'catalog_version', 'sha256:' || catalog_hash,
    'catalog_last_updated_at',
      to_char(last_updated at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'generated_at',
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'total_templates', total_count,
    'sync_mode', case when p_updated_since is null then 'full' else 'incremental' end,
    'next_cursor', next_cursor,
    'templates', items
  );
end;
$$;

revoke all on function public.integration_export_template_catalog(timestamptz, text, integer)
  from public, anon, authenticated;
grant execute on function public.integration_export_template_catalog(timestamptz, text, integer)
  to service_role;

comment on function public.integration_export_template_catalog(timestamptz, text, integer) is
  'Service-role only. Deterministic versioned export of the official care templates for the CRM/ERP mirror.';
