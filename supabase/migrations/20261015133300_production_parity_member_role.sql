-- Production parity phase A: idempotent enum addition only.
-- Keep this in a separate migration: PostgreSQL needs a commit boundary
-- before downstream routines reference the new enum label.
-- Existing super_admin and patient roles remain unchanged.
-- New registered public user role. No existing patient or admin role changes.
-- A separate committed migration must introduce the enum before we use it
-- in INSERT statements (PostgreSQL's new enum values commit boundary).
alter type public.app_role add value if not exists 'member';

