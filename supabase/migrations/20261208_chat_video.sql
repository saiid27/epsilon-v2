-- Videos in the group chat (the teacher uploads or records one and sends it).
alter table public.chat_messages add column if not exists video_url text not null default '';

-- Videos (public links, 50 MB max).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-videos', 'chat-videos', true, 52428800,
        array['video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp'])
on conflict (id) do update set public = true, file_size_limit = 52428800;

drop policy if exists "epsilon_chat_videos_insert" on storage.objects;
drop policy if exists "epsilon_chat_videos_read" on storage.objects;
create policy "epsilon_chat_videos_insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'chat-videos');
create policy "epsilon_chat_videos_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'chat-videos');
