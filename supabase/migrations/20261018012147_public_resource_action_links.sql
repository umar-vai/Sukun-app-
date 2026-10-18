-- Canonical Quran chapter references are route/number links, not copied text.
-- Existing CMS relations and approved care-plan versions remain unchanged.
create table public.plan_action_quran_surahs (
  plan_action_id uuid not null references public.plan_actions(id) on delete restrict,
  surah_number smallint not null check (surah_number between 1 and 114),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  sort_order smallint not null default 0 check (sort_order between 0 and 15),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (plan_action_id, surah_number),
  unique (plan_action_id, sort_order)
);

create index plan_action_quran_surahs_creator_idx
  on public.plan_action_quran_surahs(created_by);

alter table public.plan_action_quran_surahs enable row level security;
revoke all on public.plan_action_quran_surahs from public, anon, authenticated;
grant select, insert, delete on public.plan_action_quran_surahs to authenticated;

create policy plan_action_quran_surahs_select_permitted
on public.plan_action_quran_surahs for select to authenticated
using ((select private.is_super_admin()) or
       (select private.can_read_plan_action(plan_action_id)));

create policy plan_action_quran_surahs_insert_admin_draft
on public.plan_action_quran_surahs for insert to authenticated
with check ((select private.is_super_admin()) and exists (
  select 1 from public.plan_actions pa
  join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = plan_action_id and cp.status = 'draft'
));
create policy plan_action_quran_surahs_delete_admin_draft
on public.plan_action_quran_surahs for delete to authenticated
using ((select private.is_super_admin()) and exists (
  select 1 from public.plan_actions pa
  join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = plan_action_id and cp.status = 'draft'
));

create trigger plan_action_quran_surahs_prevent_non_draft_rewrite
before insert or update or delete on public.plan_action_quran_surahs
for each row execute function private.prevent_non_draft_resource_rewrite();

-- Only this invoker RPC can change draft links. The database validates the
-- admin role, chapter range, draft state, size, and request id before writing.
create function public.replace_draft_action_quran_surahs(
  p_action_id uuid,
  p_surahs jsonb,
  p_request_id uuid
) returns integer
language plpgsql security invoker set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  target_patient_id uuid;
  chapter jsonb;
  chapter_number integer;
  chapter_title text;
  chapter_order integer := 0;
  fingerprint text;
begin
  if caller_user_id is null or not (select private.is_super_admin()) then
    raise exception 'Super Admin access required.' using errcode = '42501';
  end if;
  select cp.patient_id into target_patient_id
  from public.plan_actions pa join public.care_plans cp on cp.id = pa.care_plan_id
  where pa.id = p_action_id and cp.status = 'draft';
  if target_patient_id is null then
    raise exception 'Only draft plan actions may be changed.' using errcode = '55000';
  end if;
  if p_request_id is null or p_surahs is null
     or jsonb_typeof(p_surahs) <> 'array'
     or jsonb_array_length(p_surahs) > 16 then
    raise exception 'Invalid Quran chapter list.' using errcode = '22023';
  end if;
  fingerprint := md5(p_surahs::text);
  if exists (
    select 1 from public.admin_audit_logs
    where actor_user_id = caller_user_id
      and action = 'plan_action.quran_surahs_replaced'
      and request_id = p_request_id
      and entity_id = p_action_id
      and metadata->>'resource_fingerprint' = fingerprint
  ) then
    return jsonb_array_length(p_surahs);
  end if;
  if exists (
    select 1 from public.admin_audit_logs
    where actor_user_id = caller_user_id
      and action = 'plan_action.quran_surahs_replaced'
      and request_id = p_request_id
  ) then
    raise exception 'Request ID cannot be reused.' using errcode = '22023';
  end if;
  -- Validate the entire request before deleting prior links.
  for chapter in select value from jsonb_array_elements(p_surahs) loop
    if jsonb_typeof(chapter) <> 'object'
       or coalesce(chapter->>'number', '') !~ '^[0-9]{1,3}$' then
      raise exception 'Invalid Quran chapter.' using errcode = '22023';
    end if;
    chapter_number := (chapter->>'number')::integer;
    chapter_title := btrim(coalesce(chapter->>'title', ''));
    if chapter_number not between 1 and 114
       or char_length(chapter_title) not between 1 and 120 then
      raise exception 'Invalid Quran chapter.' using errcode = '22023';
    end if;
  end loop;
  delete from public.plan_action_quran_surahs where plan_action_id = p_action_id;
  for chapter in select value from jsonb_array_elements(p_surahs) loop
    insert into public.plan_action_quran_surahs(
      plan_action_id,surah_number,title,sort_order,created_by
    ) values (
      p_action_id,(chapter->>'number')::smallint,
      btrim(chapter->>'title'),chapter_order::smallint,caller_user_id
    );
    chapter_order := chapter_order + 1;
  end loop;
  insert into public.admin_audit_logs(
    actor_user_id,action,entity_type,entity_id,patient_id,request_id,metadata
  ) values (
    caller_user_id,'plan_action.quran_surahs_replaced','plan_action',
    p_action_id,target_patient_id,p_request_id,
    jsonb_build_object('resource_count',chapter_order,
                       'resource_fingerprint',fingerprint)
  );
  return chapter_order;
end;
$$;
revoke all on function public.replace_draft_action_quran_surahs(uuid,jsonb,uuid)
  from public,anon;
grant execute on function public.replace_draft_action_quran_surahs(uuid,jsonb,uuid)
  to authenticated;

-- Preserve canonical links when creating a new reviewed draft version.
create or replace function public.create_draft_care_plan(
  p_patient_id uuid,
  p_name text,
  p_start_date date,
  p_end_date date default null,
  p_prescription_id uuid default null,
  p_copy_from_plan_id uuid default null,
  p_request_id uuid default gen_random_uuid()
)
returns public.care_plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_user_id uuid := (select auth.uid());
  existing_plan_id uuid;
  source_plan public.care_plans%rowtype;
  source_action public.plan_actions%rowtype;
  created_plan public.care_plans%rowtype;
  created_action_id uuid;
  next_version integer;
begin
  if caller_user_id is null then
    raise exception 'Authentication is required.' using errcode = '28000';
  end if;
  if not (select private.is_super_admin()) then
    raise exception 'Super Admin access is required.' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'A request identifier is required.' using errcode = '22023';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'Plan name is required.' using errcode = '22023';
  end if;
  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'Plan end date cannot be before its start date.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));

  select aal.entity_id into existing_plan_id
  from public.admin_audit_logs aal
  where aal.actor_user_id = caller_user_id
    and aal.action = 'care_plan.draft_created'
    and aal.request_id = p_request_id;

  if existing_plan_id is not null then
    select cp.* into created_plan
    from public.care_plans cp
    where cp.id = existing_plan_id;
    if found then return created_plan; end if;
  end if;

  perform 1
  from public.patients p
  where p.id = p_patient_id and p.status = 'active'
  for update;
  if not found then
    raise exception 'An active patient was not found.' using errcode = 'P0002';
  end if;

  select cp.* into created_plan
  from public.care_plans cp
  where cp.patient_id = p_patient_id and cp.status = 'draft'
  limit 1;
  if found then return created_plan; end if;

  if p_prescription_id is not null and not exists (
    select 1 from public.prescriptions p
    where p.id = p_prescription_id
      and p.patient_id = p_patient_id
      and p.archived_at is null
  ) then
    raise exception 'Prescription was not found for this patient.' using errcode = 'P0002';
  end if;

  if p_copy_from_plan_id is not null then
    select cp.* into source_plan
    from public.care_plans cp
    where cp.id = p_copy_from_plan_id
      and cp.patient_id = p_patient_id
      and cp.status <> 'draft';
    if not found then
      raise exception 'Source plan was not found.' using errcode = 'P0002';
    end if;
  end if;

  select coalesce(max(cp.version), 0) + 1 into next_version
  from public.care_plans cp
  where cp.patient_id = p_patient_id;

  insert into public.care_plans (
    patient_id,
    prescription_id,
    version,
    name,
    start_date,
    end_date,
    status,
    created_by
  ) values (
    p_patient_id,
    coalesce(p_prescription_id, source_plan.prescription_id),
    next_version,
    btrim(p_name),
    p_start_date,
    p_end_date,
    'draft',
    caller_user_id
  ) returning * into created_plan;

  if p_copy_from_plan_id is not null then
    for source_action in
      select pa.*
      from public.plan_actions pa
      where pa.care_plan_id = p_copy_from_plan_id
        and pa.review_status <> 'rejected'
      order by pa.sort_order, pa.created_at
    loop
      insert into public.plan_actions (
        care_plan_id, type, title, instruction, count_target,
        duration_minutes, frequency_rule, time_window, exact_time,
        start_date, end_date, sort_order, review_status,
        reminder_enabled, ai_source, created_by
      ) values (
        created_plan.id,
        source_action.type,
        source_action.title,
        source_action.instruction,
        source_action.count_target,
        source_action.duration_minutes,
        source_action.frequency_rule,
        source_action.time_window,
        source_action.exact_time,
        p_start_date,
        p_end_date,
        source_action.sort_order,
        'needs_review',
        source_action.reminder_enabled,
        null,
        caller_user_id
      ) returning id into created_action_id;

      insert into public.plan_action_resources (
        plan_action_id, content_item_id, usage_note, created_by
      )
      select
        created_action_id, par.content_item_id, par.usage_note, caller_user_id
      from public.plan_action_resources par
      where par.plan_action_id = source_action.id;

      insert into public.plan_action_quran_surahs (
        plan_action_id, surah_number, title, sort_order, created_by
      )
      select created_action_id, q.surah_number, q.title, q.sort_order, caller_user_id
      from public.plan_action_quran_surahs q
      where q.plan_action_id = source_action.id;
    end loop;
  end if;

  insert into public.admin_audit_logs (
    actor_user_id, action, entity_type, entity_id, patient_id,
    request_id, metadata
  ) values (
    caller_user_id,
    'care_plan.draft_created',
    'care_plan',
    created_plan.id,
    created_plan.patient_id,
    p_request_id,
    jsonb_build_object(
      'version', created_plan.version,
      'copied_from_plan_id', p_copy_from_plan_id
    )
  );

  return created_plan;
end;
$$;


