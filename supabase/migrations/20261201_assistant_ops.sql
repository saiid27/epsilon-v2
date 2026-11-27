-- Assistant operations: failed calls to Claude (to see when the service is
-- about to stop), and the balance the admin last entered from the Claude console.
create table if not exists public.assistant_errors (
  id uuid primary key default gen_random_uuid(),
  status int not null default 0,
  message text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_assistant_errors_time on public.assistant_errors(created_at desc);
alter table public.assistant_errors enable row level security;
drop policy if exists "epsilon_public_assistant_errors" on public.assistant_errors;
create policy "epsilon_public_assistant_errors" on public.assistant_errors
  for all using (true) with check (true);

insert into public.app_settings(key, value)
values ('anthropicBalanceUsd', '0'), ('anthropicBalanceSetAt', now()::text)
on conflict (key) do nothing;
