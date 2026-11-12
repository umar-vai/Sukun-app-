-- The member's Routine hub lists routines an admin set for them first, then
-- the ones they made themselves. Whether a routine came from an admin is only
-- recorded in admin_audit_logs, which members cannot read. This read-only
-- helper returns just the caller's own routine ids that an admin created, so
-- no audit detail (actor, payload) is exposed and no schema changes.

create or replace function public.my_admin_assigned_routine_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select pr.id
  from public.personal_routines pr
  where pr.owner_user_id = (select auth.uid())
    and exists (
      select 1
      from public.admin_audit_logs aal
      where aal.entity_type = 'personal_routine'
        and aal.entity_id = pr.id
        and aal.action in (
          'personal_routine.delegated_draft_created',
          'personal_routine.delegated_reminders_imported'
        )
    );
$$;

revoke all on function public.my_admin_assigned_routine_ids()
  from public, anon;
grant execute on function public.my_admin_assigned_routine_ids()
  to authenticated;
