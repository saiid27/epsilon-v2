-- The French name of a subject, shown in its group (the logo and the title).
alter table public.subjects add column if not exists name_fr text not null default '';

-- Polls in the group: a message can carry a question and its options.
alter table public.chat_messages add column if not exists poll_question text not null default '';
alter table public.chat_messages add column if not exists poll_options jsonb not null default '[]'::jsonb;

create table if not exists public.chat_poll_votes (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  option_index int not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
alter table public.chat_poll_votes enable row level security;
drop policy if exists "epsilon_public_chat_poll_votes" on public.chat_poll_votes;
create policy "epsilon_public_chat_poll_votes" on public.chat_poll_votes
  for all using (true) with check (true);
