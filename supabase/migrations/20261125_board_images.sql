-- Images a teacher puts on the live whiteboard (a lesson or a solution).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('live-board', 'live-board', true, 5242880, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = 5242880,
      allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp'];

drop policy if exists "epsilon_live_board_insert" on storage.objects;
drop policy if exists "epsilon_live_board_read" on storage.objects;
create policy "epsilon_live_board_insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'live-board');
create policy "epsilon_live_board_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'live-board');
