-- Students choose the faculty, track and subject of their file; a subject
-- that is not in the list is typed in (subject_name) and checked by the
-- administration before the file is published.
alter table public.student_files add column if not exists subject_name text not null default '';
