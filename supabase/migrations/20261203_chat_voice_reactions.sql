-- Voice messages and emoji reactions in the subject chat groups.
alter table public.chat_messages add column if not exists audio_url text not null default '';
alter table public.chat_messages add column if not exists audio_seconds int not null default 0;

create table if not exists public.chat_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);
create index if not exists idx_chat_reactions_message on public.chat_reactions(message_id);
alter table public.chat_reactions enable row level security;
drop policy if exists "epsilon_public_chat_reactions" on public.chat_reactions;
create policy "epsilon_public_chat_reactions" on public.chat_reactions
  for all using (true) with check (true);

-- Voice notes (public links, 7 MB max).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-audio', 'chat-audio', true, 7340032,
        array['audio/mp4', 'audio/aac', 'audio/m4a', 'audio/webm', 'audio/ogg', 'audio/wav'])
on conflict (id) do update set public = true, file_size_limit = 7340032;

drop policy if exists "epsilon_chat_audio_insert" on storage.objects;
drop policy if exists "epsilon_chat_audio_read" on storage.objects;
create policy "epsilon_chat_audio_insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'chat-audio');
create policy "epsilon_chat_audio_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'chat-audio');
