-- Server-owned AI request idempotency and provider-slot health state.
-- Neither table is client-readable; Gemini credentials are never persisted.

create table public.ai_generation_requests (
  request_id uuid primary key,
  care_plan_id uuid not null references public.care_plans (id) on delete restrict,
  prescription_id uuid not null references public.prescriptions (id) on delete restrict,
  requested_by uuid not null references auth.users (id) on delete restrict,
  status text not null default 'processing',
  normalized_result jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_generation_requests_status check (
    status in ('processing', 'succeeded', 'manual_required')
  ),
  constraint ai_generation_requests_result check (
    (status = 'processing' and normalized_result is null)
    or (status <> 'processing' and jsonb_typeof(normalized_result) = 'object')
  )
);

create index ai_generation_requests_plan_created_idx
  on public.ai_generation_requests (care_plan_id, created_at desc);
create index ai_generation_requests_requester_created_idx
  on public.ai_generation_requests (requested_by, created_at desc);

create table public.ai_provider_slot_health (
  slot_id smallint primary key,
  status text not null default 'healthy',
  failure_type text,
  failed_at timestamptz,
  retry_after timestamptz,
  consecutive_failures integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint ai_provider_slot_health_slot_range check (slot_id between 1 and 4),
  constraint ai_provider_slot_health_status check (
    status in ('healthy', 'cooling_down', 'disabled')
  ),
  constraint ai_provider_slot_health_failures_nonnegative check (
    consecutive_failures >= 0
  ),
  constraint ai_provider_slot_health_state check (
    (status = 'healthy' and failure_type is null and retry_after is null)
    or (status = 'cooling_down' and failure_type is not null and retry_after is not null)
    or (status = 'disabled' and failure_type is not null)
  )
);

insert into public.ai_provider_slot_health (slot_id)
values (1), (2), (3), (4);

alter table public.ai_generation_requests enable row level security;
alter table public.ai_provider_slot_health enable row level security;

revoke all on public.ai_generation_requests from public, anon, authenticated;
revoke all on public.ai_provider_slot_health from public, anon, authenticated;

comment on table public.ai_generation_requests is
  'Server-only idempotency records for normalized prescription action suggestions; contains no provider credentials.';
comment on table public.ai_provider_slot_health is
  'Server-only cooldown state for Gemini slots 1-4; never stores credential values.';
