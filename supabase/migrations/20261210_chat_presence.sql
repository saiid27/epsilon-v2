-- Who is in a group right now: each open chat refreshes its row every minute.
create table if not exists public.chat_presence (
  group_id uuid not null references public.chat_groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
alter table public.chat_presence enable row level security;
drop policy if exists "epsilon_public_chat_presence" on public.chat_presence;
create policy "epsilon_public_chat_presence" on public.chat_presence
  for all using (true) with check (true);
