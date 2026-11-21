-- Files shared by students with their specialty (faculty, track, level).
-- A file is visible once the administration approves it. The uploader gets
-- 50 000 input and 5 000 output assistant tokens on approval (once).
-- Run after 20261119_tokens.sql.

create table if not exists public.student_files (
  id uuid primary key default gen_random_uuid(),
  uploader_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  description text not null default '',
  subject_id uuid references public.subjects(id) on delete set null,
  faculty text not null default '',
  track text not null default '',
  level text not null default '',
  file_path text not null,
  file_url text not null,
  file_type text not null default 'pdf',
  size_bytes int not null default 0,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  downloads int not null default 0,
  rewarded boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_student_files_specialty
  on public.student_files(status, faculty, track, level, created_at desc);
alter table public.student_files enable row level security;

drop policy if exists "epsilon_public_read_student_files" on public.student_files;
drop policy if exists "epsilon_public_insert_student_files" on public.student_files;
drop policy if exists "epsilon_public_update_student_files" on public.student_files;
drop policy if exists "epsilon_public_delete_student_files" on public.student_files;
create policy "epsilon_public_read_student_files" on public.student_files for select using (true);
create policy "epsilon_public_insert_student_files" on public.student_files for insert with check (true);
create policy "epsilon_public_update_student_files" on public.student_files for update using (true) with check (true);
create policy "epsilon_public_delete_student_files" on public.student_files for delete using (true);

-- Reward once, when the file is approved.
create or replace function public.epsilon_student_file_reward()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'approved' and not new.rewarded then
    insert into public.assistant_bonus(user_id, input_tokens, output_tokens, reason)
    values (new.uploader_id, 50000, 5000, 'upload');
    new.rewarded := true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_epsilon_student_file_reward on public.student_files;
create trigger trg_epsilon_student_file_reward
  before update on public.student_files
  for each row execute function public.epsilon_student_file_reward();

-- Storage bucket for the files (public links, 7 MB max, PDF and images).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('student-files', 'student-files', true, 7340032,
        array['application/pdf', 'image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = 7340032,
      allowed_mime_types = array['application/pdf', 'image/png', 'image/jpeg', 'image/webp'];

drop policy if exists "epsilon_student_files_insert" on storage.objects;
drop policy if exists "epsilon_student_files_read" on storage.objects;
create policy "epsilon_student_files_insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'student-files');
create policy "epsilon_student_files_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'student-files');
