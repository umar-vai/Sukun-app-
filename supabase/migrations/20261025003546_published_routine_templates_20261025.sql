-- Additive, nonclinical, Admin-curated routine templates.
-- Personal copies are owner-isolated; patient prescriptions are never mutated.
create table public.routine_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  description text check (description is null or char_length(description) <= 500),
  status text not null default 'draft'
    check (status in ('draft','published','archived')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.routine_template_steps (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.routine_templates(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 160),
  sort_order integer not null default 0 check (sort_order between 0 and 999),
  created_at timestamptz not null default now()
);
create index routine_templates_status_idx on public.routine_templates(status,created_at desc);
create index routine_template_steps_order_idx on public.routine_template_steps(template_id,sort_order,created_at);
alter table public.routine_templates enable row level security;
alter table public.routine_template_steps enable row level security;

-- Admin-only draft management, public published read for signed-in users.
create policy routine_templates_read_visible on public.routine_templates
  for select to authenticated using (
    status = 'published' or (select private.is_super_admin())
  );
create policy routine_templates_admin_insert on public.routine_templates
  for insert to authenticated with check (
    (select private.is_super_admin()) and created_by = (select auth.uid())
  );
create policy routine_templates_admin_update on public.routine_templates
  for update to authenticated using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));
create policy routine_templates_admin_delete on public.routine_templates
  for delete to authenticated using ((select private.is_super_admin()));

create policy routine_template_steps_read_visible on public.routine_template_steps
  for select to authenticated using (exists (
    select 1 from public.routine_templates t
    where t.id = template_id and
      (t.status = 'published' or (select private.is_super_admin()))
  ));
-- Change published templates only after unpublishing, preserving the
-- exact actions a user chose when opting into the template.
create policy routine_template_steps_admin_insert on public.routine_template_steps
  for insert to authenticated with check (
    (select private.is_super_admin()) and exists (
      select 1 from public.routine_templates t
      where t.id = template_id and t.status = 'draft'
    )
  );
create policy routine_template_steps_admin_update on public.routine_template_steps
  for update to authenticated
  using ((select private.is_super_admin()) and exists (
    select 1 from public.routine_templates t
    where t.id = template_id and t.status = 'draft'
  ))
  with check ((select private.is_super_admin()) and exists (
    select 1 from public.routine_templates t
    where t.id = template_id and t.status = 'draft'
  ));
create policy routine_template_steps_admin_delete on public.routine_template_steps
  for delete to authenticated using (
    (select private.is_super_admin()) and exists (
      select 1 from public.routine_templates t
      where t.id = template_id and t.status = 'draft'
    )
  );
revoke all on public.routine_templates from anon;
revoke all on public.routine_template_steps from anon;
grant select,insert,update,delete on public.routine_templates to authenticated;
grant select,insert,update,delete on public.routine_template_steps to authenticated;

-- SECURITY INVOKER: the caller must see the published template AND own
-- every inserted routine/action according to the existing RLS policies.
create function public.adopt_published_routine_template(p_template_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_owner uuid := (select auth.uid());
  v_title text;
  v_new uuid;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  select t.title into v_title
  from public.routine_templates t
  where t.id = p_template_id and t.status = 'published';
  if v_title is null then raise exception 'Published template unavailable'; end if;
  if not exists (
    select 1 from public.routine_template_steps s
    where s.template_id = p_template_id
  ) then raise exception 'Published template has no actions'; end if;

  insert into public.personal_routines(owner_user_id,title)
  values(v_owner,v_title) returning id into v_new;

  insert into public.personal_routine_actions
    (routine_id,owner_user_id,title,notification_title,schedule_kind,resource_provider)
  select v_new,v_owner,s.title,s.title,'manual','manual'
  from public.routine_template_steps s
  where s.template_id = p_template_id
  order by s.sort_order,s.created_at,s.id;
  return v_new;
end;
$$;
revoke all on function public.adopt_published_routine_template(uuid) from public, anon;
grant execute on function public.adopt_published_routine_template(uuid) to authenticated;
comment on table public.routine_templates is
  'Admin-published reusable personal routine templates; never clinical patient prescriptions.';
