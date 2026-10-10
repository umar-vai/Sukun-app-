-- STAGING ONLY. Never add this one-off reconciliation to automatic
-- Production migrations. Run only against Supabase project
-- qacklgqvxvjjzsimjoip AFTER the reviewed role-exclusive finalizer
-- migration has been applied and the live account checks below pass.
-- This intentionally touches exactly QA Test Patient A and B.
begin;
do $qa_role_repair$
declare
  matching_patients integer;
  overlapping_roles integer;
begin
  select count(*) into matching_patients
  from public.patients p
  join auth.users u on u.id = p.user_id
  join public.profiles pr on pr.id = p.user_id
  where p.full_name in ('QA Test Patient A','QA Test Patient B')
    and p.status = 'active'
    and pr.requires_credential_change = true
    and exists(select 1 from public.user_roles ur
      where ur.user_id = p.user_id and ur.role = 'patient')
    and not exists(select 1 from public.user_roles ur
      where ur.user_id = p.user_id and ur.role = 'super_admin');

  select count(*) into overlapping_roles
  from public.user_roles ur
  join public.patients p on p.user_id = ur.user_id
  where p.full_name in ('QA Test Patient A','QA Test Patient B')
    and ur.role = 'member';

  if matching_patients <> 2 or overlapping_roles <> 2
    or (select count(*) from public.patients) <> 2
    or (select count(*) from public.user_roles
      where role='super_admin') <> 1
  then
    raise exception 'STAGING RECONCILIATION ABORTED: QA account/role baseline changed';
  end if;

  delete from public.user_roles ur using public.patients p
    where ur.user_id = p.user_id
      and ur.role = 'member'
      and p.full_name in ('QA Test Patient A','QA Test Patient B');

  if found is not true then
    raise exception 'No role removed; transaction aborted';
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, metadata
  ) values (
    null,
    'staging.qa_patient_member_grants_reconciled',
    'user_role',
    jsonb_build_object(
      'environment','staging',
      'removed_extraneous_member_roles', overlapping_roles,
      'patient_data_modified',false
    )
  );
end $qa_role_repair$;
commit;

-- Verify after commit:
-- select p.full_name,array_agg(r.role::text order by r.role::text) as roles
-- from public.patients p join public.user_roles r on r.user_id=p.user_id
-- where p.full_name in ('QA Test Patient A','QA Test Patient B')
-- group by p.full_name order by p.full_name;
