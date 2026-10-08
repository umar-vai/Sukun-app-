-- Prelaunch patient inbox: permit only the authenticated owner to mark
-- an already sent event as opened. No client-supplied patient identity.
-- Server-only scheduled, failed and cancelled events cannot be marked opened.
-- RLS SELECT continues to protect history; direct UPDATE remains admin-only.
create or replace function public.mark_patient_notification_opened(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_patient_id uuid;
  matched_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;

  caller_patient_id := (select private.current_patient_id());
  if caller_patient_id is null or p_notification_id is null then
    return false;
  end if;

  update public.notification_events ne
  set
    status = 'opened'::public.notification_status,
    opened_at = coalesce(ne.opened_at, now())
  where ne.id = p_notification_id
    and ne.patient_id = caller_patient_id
    and ne.status in ('sent', 'opened')
    and ne.scheduled_at <= now()
  returning ne.id into matched_id;

  return matched_id is not null;
end;
$$;

revoke execute on function public.mark_patient_notification_opened(uuid)
  from public, anon, authenticated;
grant execute on function public.mark_patient_notification_opened(uuid)
  to authenticated;

comment on function public.mark_patient_notification_opened(uuid) is
  'Allows only the authenticated patient to mark an already sent own event as opened; no arbitrary status or patient ID is accepted.';
