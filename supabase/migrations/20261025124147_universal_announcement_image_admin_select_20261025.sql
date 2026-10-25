-- Super Admin uploads/deletes only non-clinical, public notice artwork.
-- Supabase Storage API remove requires both SELECT and DELETE on objects;
-- the initial announcement migration provided INSERT+DELETE but not SELECT.
-- Public getPublicUrl needs no user-specific read policy, but verified admins
-- must be able to select their own publicly served notice assets for cleanup.
create policy sukun_announcement_image_admin_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'sukun-announcement-images'
    and (select private.is_super_admin())
  );
