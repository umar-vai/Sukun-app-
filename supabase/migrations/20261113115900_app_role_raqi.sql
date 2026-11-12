-- Raqi staff role, part 1 (owner request 2026-11-12). A new enum value must
-- be committed before any function or row can use it, so it is added alone
-- here; 20261113120000_raqi_staff_role.sql does the rest. Nothing uses the
-- value until that migration runs.

alter type public.app_role add value if not exists 'raqi';
