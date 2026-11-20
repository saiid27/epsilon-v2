-- Assistant packages (basic, standard, pro), bought apart from subjects.
-- A student's request waits for admin approval with the receipt, like subjects.
create table if not exists public.assistant_subscriptions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.users(id) on delete cascade,
  tier text not null check (tier in ('basic', 'standard', 'pro')),
  period text not null default 'monthly' check (period in ('monthly', 'yearly')),
  amount int not null default 0,
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  receipt_url text not null default '',
  transaction_ref text not null default '',
  status text not null default 'pending' check (status in ('pending', 'active', 'rejected', 'expired')),
  rejection_reason text not null default '',
  starts_at timestamptz,
  expires_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_assistant_subs_student on public.assistant_subscriptions(student_id, status, expires_at);
alter table public.assistant_subscriptions enable row level security;
drop policy if exists "epsilon_public_assistant_subs" on public.assistant_subscriptions;
create policy "epsilon_public_assistant_subs" on public.assistant_subscriptions
  for all using (true) with check (true);

-- When an admin approves: the subscription starts now and lasts one month or one year.
create or replace function public.epsilon_assistant_activate()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'active' and (old.status is distinct from 'active') then
    new.starts_at := coalesce(new.starts_at, now());
    new.expires_at := new.starts_at
      + case when new.period = 'yearly' then interval '1 year' else interval '1 month' end;
    new.reviewed_at := coalesce(new.reviewed_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_epsilon_assistant_activate on public.assistant_subscriptions;
create trigger trg_epsilon_assistant_activate
  before update on public.assistant_subscriptions
  for each row execute function public.epsilon_assistant_activate();
