-- One chat group per subject, like a WhatsApp group. The teacher can lock it
-- (only the teacher writes) and unlock it (students ask their questions).
create table if not exists public.chat_groups (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null unique references public.subjects(id) on delete cascade,
  locked boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.chat_groups enable row level security;
drop policy if exists "epsilon_public_chat_groups" on public.chat_groups;
create policy "epsilon_public_chat_groups" on public.chat_groups
  for all using (true) with check (true);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.chat_groups(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  sender_name text not null default '',
  body text not null default '',
  image_url text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_chat_messages_group on public.chat_messages(group_id, created_at);
alter table public.chat_messages enable row level security;
drop policy if exists "epsilon_public_chat_messages" on public.chat_messages;
create policy "epsilon_public_chat_messages" on public.chat_messages
  for all using (true) with check (true);

-- While the group is locked, only teachers and admins can post.
create or replace function public.epsilon_chat_lock_check()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_locked boolean;
  sender_role text;
begin
  select locked into is_locked from public.chat_groups where id = new.group_id;
  select role into sender_role from public.users where id = new.sender_id;
  if coalesce(is_locked, false)
     and coalesce(sender_role, '') not in ('teacher', 'admin', 'developer') then
    raise exception 'المجموعة مقفلة الآن. ينتظر الأستاذ لفتحها.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_epsilon_chat_lock on public.chat_messages;
create trigger trg_epsilon_chat_lock
  before insert on public.chat_messages
  for each row execute function public.epsilon_chat_lock_check();

-- Images sent in the chat (public links, 7 MB max).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-images', 'chat-images', true, 7340032,
        array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 7340032;

drop policy if exists "epsilon_chat_images_insert" on storage.objects;
drop policy if exists "epsilon_chat_images_read" on storage.objects;
create policy "epsilon_chat_images_insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'chat-images');
create policy "epsilon_chat_images_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'chat-images');
