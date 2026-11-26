-- Usernames: each student picks a unique username, shown in the groups.
alter table public.users add column if not exists username text;
alter table public.users drop constraint if exists users_username_format;
alter table public.users add constraint users_username_format
  check (username is null or username ~ '^[a-z0-9_]{3,20}$');
create unique index if not exists users_username_key
  on public.users (username) where username is not null;

-- A private conversation between one student and one teacher.
create table if not exists public.direct_threads (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.users(id) on delete cascade,
  teacher_id uuid not null references public.users(id) on delete cascade,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (student_id, teacher_id)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.direct_threads(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  body text not null default '',
  image_url text not null default '',
  forwarded boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_direct_messages_thread
  on public.direct_messages (thread_id, created_at);

alter table public.direct_threads enable row level security;
alter table public.direct_messages enable row level security;
drop policy if exists "epsilon_public_direct_threads" on public.direct_threads;
create policy "epsilon_public_direct_threads" on public.direct_threads
  for all using (true) with check (true);
drop policy if exists "epsilon_public_direct_messages" on public.direct_messages;
create policy "epsilon_public_direct_messages" on public.direct_messages
  for all using (true) with check (true);
