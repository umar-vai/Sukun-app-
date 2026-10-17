-- Additive, owner-scoped links for user/patient *personal* routines.
-- Admin-approved clinical plan_action_resources remain untouched.
create table public.personal_routine_action_resources (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null,
  owner_user_id uuid not null,
  provider text not null check (provider in ('cms','quran','hadith')),
  content_item_id uuid references public.content_items(id) on delete restrict,
  external_resource_ref text,
  sort_order smallint not null default 0 check (sort_order between 0 and 999),
  created_at timestamptz not null default now(),
  constraint personal_routine_resource_owner_fk
    foreign key (action_id,owner_user_id)
    references public.personal_routine_actions(id,owner_user_id)
    on delete cascade,
  constraint personal_routine_resource_shape check (
    (provider='cms' and content_item_id is not null and external_resource_ref is null)
    or
    (provider in ('quran','hadith') and content_item_id is null and
      external_resource_ref is not null and
      char_length(external_resource_ref) between 1 and 120 and
      external_resource_ref ~ '^[A-Za-z0-9:_/-]+$')
  )
);

create unique index personal_routine_resource_unique_cms
on public.personal_routine_action_resources(action_id,content_item_id)
where provider='cms';
create unique index personal_routine_resource_unique_external
on public.personal_routine_action_resources(action_id,provider,external_resource_ref)
where provider in ('quran','hadith');
create unique index personal_routine_resource_order_unique
on public.personal_routine_action_resources(action_id,sort_order);
create index personal_routine_resource_owner_idx
on public.personal_routine_action_resources(owner_user_id,action_id);

alter table public.personal_routine_action_resources enable row level security;
create policy personal_resource_select_self
on public.personal_routine_action_resources for select to authenticated
using (owner_user_id=(select auth.uid()));
create policy personal_resource_insert_self
on public.personal_routine_action_resources for insert to authenticated
with check (
  owner_user_id=(select auth.uid()) and
  (provider!='cms' or exists (
    select 1 from public.content_items c
    where c.id=content_item_id and c.status='published'
      and c.visibility='public'
  ))
);
create policy personal_resource_update_self
on public.personal_routine_action_resources for update to authenticated
using (owner_user_id=(select auth.uid()))
with check (
  owner_user_id=(select auth.uid()) and
  (provider!='cms' or exists (
    select 1 from public.content_items c
    where c.id=content_item_id and c.status='published'
      and c.visibility='public'
  ))
);
create policy personal_resource_delete_self
on public.personal_routine_action_resources for delete to authenticated
using (owner_user_id=(select auth.uid()));

revoke all on public.personal_routine_action_resources from anon;
grant select,insert,update,delete
on public.personal_routine_action_resources to authenticated;

comment on table public.personal_routine_action_resources is
 'Owner-only ordered references for personal routines. Neither these links nor personal routines can mutate clinician-approved patient care plans. Canonical Quran/Hadith refs are validated on read by the app; never treat refs as verified text.';

-- Existing single CMS link on personal_routine_actions is retained
-- for backwards compatibility. UI reads it only as a legacy fallback.

-- Atomic, SECURITY INVOKER replacement for a user's own routine action.
-- The RLS policies remain the authority for both child rows and CMS items.
create or replace function public.replace_personal_action_resources(
  p_action_id uuid,
  p_resources jsonb
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  item jsonb;
  ord integer := 0;
  resource_kind text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.personal_routine_actions a
    where a.id = p_action_id and a.owner_user_id = (select auth.uid())
  ) then
    raise exception 'Not authorized to edit this routine action'
      using errcode = '42501';
  end if;
  if p_resources is null or jsonb_typeof(p_resources) <> 'array'
    or jsonb_array_length(p_resources) > 16 then
    raise exception 'Invalid or oversized resource list' using errcode = '22023';
  end if;
  delete from public.personal_routine_action_resources
  where action_id = p_action_id and owner_user_id = (select auth.uid());
  for item in select value from jsonb_array_elements(p_resources) loop
    resource_kind := item->>'provider';
    if resource_kind not in ('cms','quran','hadith') then
      raise exception 'Unsupported resource provider' using errcode = '22023';
    end if;
    insert into public.personal_routine_action_resources(
      action_id,owner_user_id,provider,content_item_id,
      external_resource_ref,sort_order
    ) values (
      p_action_id,(select auth.uid()),resource_kind,
      case when resource_kind = 'cms'
        then (item->>'content_item_id')::uuid else null end,
      case when resource_kind != 'cms'
        then item->>'external_resource_ref' else null end,
      ord
    );
    ord := ord + 1;
  end loop;
end;
$$;
revoke all on function public.replace_personal_action_resources(uuid,jsonb)
  from public,anon;
grant execute on function public.replace_personal_action_resources(uuid,jsonb)
  to authenticated;
