-- Cover Phase 4B attachment foreign keys used by audit/support queries.

create index prescription_attachments_care_plan_idx
  on public.prescription_attachments (care_plan_id)
  where care_plan_id is not null;

create index prescription_attachments_uploaded_by_idx
  on public.prescription_attachments (uploaded_by, created_at desc);

