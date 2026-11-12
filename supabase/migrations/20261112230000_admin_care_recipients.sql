-- Admin "Patients" list (owner request 2026-11-12).
--
-- The admin Users tab listed every app account. The owner wants only the
-- people under care there: accounts with the `patient` role and members an
-- admin has already set a routine for. Anyone else is reached by searching
-- (name, email or phone) so the admin can start care for them.
--
-- * Read-only SECURITY DEFINER function, Super Admin checked in the database.
-- * Returns no clinical text; only name, contact, role and whether an admin
--   routine exists. Email/phone come from auth.users, which the client can
--   not read directly.
-- * No table, policy or data change.

create or replace function public.admin_list_care_recipients(
  p_query text default null,
  p_limit integer default 40,
  p_offset integer default 0
)
returns table (
  user_id uuid,
  display_name text,
  email text,
  phone text,
  is_patient boolean,
  patient_id uuid,
  patient_code text,
  has_admin_routine boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_term text := nullif(btrim(coalesce(p_query, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if not (select private.is_super_admin()) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if v_term is not null and char_length(v_term) > 120 then
    raise exception 'query too long' using errcode = '22023';
  end if;

  return query
  with base as (
    select
      u.id as uid,
      p.display_name as pname,
      u.email::text as uemail,
      coalesce(u.phone::text, pt.phone) as uphone,
      exists (
        select 1 from public.user_roles ur
        where ur.user_id = u.id and ur.role = 'patient'
      ) as patient_role,
      pt.id as pid,
      pt.patient_code as pcode,
      pt.full_name as pfull,
      exists (
        select 1
        from public.personal_routines pr
        join public.admin_audit_logs aal
          on aal.entity_type = 'personal_routine'
         and aal.entity_id = pr.id
         and aal.action in (
           'personal_routine.delegated_draft_created',
           'personal_routine.delegated_reminders_imported'
         )
        where pr.owner_user_id = u.id
      ) as admin_routine,
      u.created_at as ucreated
    from auth.users u
    left join public.profiles p on p.id = u.id
    left join lateral (
      select x.id, x.patient_code, x.full_name, x.phone
      from public.patients x
      where x.user_id = u.id and x.archived_at is null
      order by x.created_at desc
      limit 1
    ) pt on true
    where not exists (
      select 1 from public.user_roles ur
      where ur.user_id = u.id and ur.role = 'super_admin'
    )
  )
  select
    b.uid,
    coalesce(nullif(btrim(b.pname), ''), b.pfull),
    b.uemail,
    b.uphone,
    (b.patient_role or b.pid is not null),
    b.pid,
    b.pcode,
    b.admin_routine,
    b.ucreated
  from base b
  where
    case
      when v_term is null then
        b.patient_role or b.pid is not null or b.admin_routine
      else
        b.uid::text = v_term
        or coalesce(b.pname, '') ilike '%' || v_term || '%'
        or coalesce(b.pfull, '') ilike '%' || v_term || '%'
        or coalesce(b.uemail, '') ilike '%' || v_term || '%'
        or coalesce(b.uphone, '') ilike '%' || v_term || '%'
        or coalesce(b.pcode, '') ilike '%' || v_term || '%'
    end
  order by
    (b.patient_role or b.pid is not null or b.admin_routine) desc,
    b.ucreated desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.admin_list_care_recipients(text, integer, integer)
  from public, anon;
grant execute on function public.admin_list_care_recipients(text, integer, integer)
  to authenticated;

comment on function public.admin_list_care_recipients(text, integer, integer) is
  'Super Admin: people under care (patients and members with an admin routine); search reaches every non-admin account.';
