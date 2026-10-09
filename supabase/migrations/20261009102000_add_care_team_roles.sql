-- Least-privileged team roles; existing patient/admin roles are untouched.
alter type public.app_role add value if not exists 'raqi';
alter type public.app_role add value if not exists 'support_staff';
