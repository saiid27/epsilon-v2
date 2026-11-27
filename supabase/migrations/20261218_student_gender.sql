-- A student's gender: a student without a photo shows the matching illustration.
alter table public.users add column if not exists gender text;
alter table public.users drop constraint if exists users_gender_check;
alter table public.users add constraint users_gender_check
  check (gender is null or gender in ('male', 'female'));
