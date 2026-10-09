-- New registered public user role. No existing patient or admin role changes.
-- A separate committed migration must introduce the enum before we use it
-- in INSERT statements (PostgreSQL's new enum values commit boundary).
alter type public.app_role add value if not exists 'member';
