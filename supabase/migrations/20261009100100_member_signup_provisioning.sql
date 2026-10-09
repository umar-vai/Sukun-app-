-- Accounts created through email, phone OTP, or an OAuth provider must
-- receive only a nonclinical member identity by default. Never derive any
-- patient, raqi, support, or admin permission from user-supplied metadata.
create or replace function private.provision_public_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, locale, requires_credential_change)
  values (new.id, 'bn', false)
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role, granted_by)
  values (new.id, 'member'::public.app_role, null)
  on conflict (user_id, role) do nothing;

  return new;
end;
$$;

revoke all on function private.provision_public_member()
  from public, anon, authenticated;

drop trigger if exists provision_public_member_after_signup on auth.users;
create trigger provision_public_member_after_signup
after insert on auth.users
for each row execute function private.provision_public_member();

comment on function private.provision_public_member() is
  'Creates a Bangla public profile and a member-only role for new Auth users; never grants clinical or staff permissions.';
