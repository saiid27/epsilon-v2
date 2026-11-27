-- Each section's features have their own price. A price of 0 means the
-- feature is not activated for that section yet.
alter table public.courses add column if not exists feature_groups_price int not null default 0;
alter table public.courses add column if not exists feature_videos_price int not null default 0;
alter table public.courses add column if not exists feature_live_price int not null default 0;
alter table public.courses add column if not exists feature_assistant_price int not null default 0;

-- A student's subscription to one feature of a section.
create table if not exists public.section_feature_subscriptions (
  id uuid primary key default gen_random_uuid(),
  request_ref text not null default ('EPS-' || to_char(now(), 'YYMMDD') || lpad((floor(random() * 1000))::int::text, 3, '0')),
  student_id uuid not null references public.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  feature text not null check (feature in ('groups', 'videos', 'live', 'assistant')),
  amount int not null default 0,
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  receipt_url text not null default '',
  transaction_ref text not null default '',
  status text not null default 'pending' check (status in ('pending', 'active', 'expired', 'rejected')),
  rejection_reason text not null default '',
  starts_at timestamptz,
  expires_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.section_feature_subscriptions enable row level security;
drop policy if exists "epsilon_public_section_feature_subscriptions" on public.section_feature_subscriptions;
create policy "epsilon_public_section_feature_subscriptions" on public.section_feature_subscriptions
  for all using (true) with check (true);
