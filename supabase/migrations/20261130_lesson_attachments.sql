-- Files and images the admin attaches to a subject (for subscribers), and
-- optionally to one lesson (video) of that subject. lesson_id null = subject file.
create table if not exists public.lesson_attachments (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  lesson_id uuid references public.lessons(id) on delete cascade,
  title text not null,
  kind text not null default 'pdf' check (kind in ('pdf', 'image')),
  url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_lesson_attachments_lesson on public.lesson_attachments(lesson_id);
create index if not exists idx_lesson_attachments_subject on public.lesson_attachments(subject_id);
alter table public.lesson_attachments enable row level security;
drop policy if exists "epsilon_public_lesson_attachments" on public.lesson_attachments;
create policy "epsilon_public_lesson_attachments" on public.lesson_attachments
  for all using (true) with check (true);

-- Storage for these files (public links, 7 MB max, PDF and images).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lesson-files', 'lesson-files', true, 7340032,
        array['application/pdf', 'image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = 7340032;

drop policy if exists "epsilon_lesson_files_insert" on storage.objects;
drop policy if exists "epsilon_lesson_files_read" on storage.objects;
create policy "epsilon_lesson_files_insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'lesson-files');
create policy "epsilon_lesson_files_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'lesson-files');
