-- Epsilon Supabase schema
-- Run this file once in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  level text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  class_id uuid references public.classes(id) on delete set null,
  description text not null default '',
  price text not null default '',
  renewal_months int not null default 1,
  subjects jsonb not null default '[]'::jsonb,
  subject_details jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null unique,
  password text not null,
  role text not null default 'student' check (role in ('admin', 'teacher', 'student')),
  status text not null default 'pending' check (status in ('pending', 'active', 'blocked', 'rejected')),
  class_id uuid references public.classes(id) on delete set null,
  course_id uuid references public.courses(id) on delete set null,
  subject text,
  selected_subjects jsonb not null default '[]'::jsonb,
  payment_proof_url text,
  payment_sender_phone text,
  active_device_id text,
  payment_amount text,
  password_reset_code text,
  password_reset_expires_at timestamptz,
  subscription_expires_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.users add column if not exists payment_amount text;
alter table public.users add column if not exists password_reset_code text;
alter table public.users add column if not exists password_reset_expires_at timestamptz;
alter table public.users add column if not exists subscription_expires_at timestamptz;
alter table public.courses add column if not exists renewal_months int not null default 1;

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  url text not null default '',
  teacher_id uuid references public.users(id) on delete set null,
  class_id uuid references public.classes(id) on delete set null,
  course_id uuid references public.courses(id) on delete cascade,
  subject text not null default '',
  is_published boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  account_number text not null,
  image_url text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.guest_content (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('guest_video', 'archive_file')),
  title text not null,
  url text not null default '',
  description text not null default '',
  course_id uuid references public.courses(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.offer_slides (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  image_url text not null default '',
  duration_seconds int not null default 5,
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.national_exam_results (
  id uuid primary key default gen_random_uuid(),
  exam_type text not null,
  candidate_number text,
  full_name text not null,
  birth_place text not null default '',
  birth_date text not null default '',
  wilaya text not null default '',
  moughataa text not null default '',
  center_name text not null default '',
  score text not null default '',
  decision text not null default '',
  rank text not null default '',
  raw_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_courses_active on public.courses(is_active, created_at);
create index if not exists idx_lessons_course on public.lessons(course_id, created_at desc);
create index if not exists idx_guest_content_type on public.guest_content(content_type, active, created_at desc);
create index if not exists idx_notifications_created on public.notifications(created_at desc);
create index if not exists idx_results_exam_number on public.national_exam_results(exam_type, candidate_number);
create index if not exists idx_results_exam_name on public.national_exam_results(exam_type, lower(full_name));

alter table public.classes enable row level security;
alter table public.courses enable row level security;
alter table public.users enable row level security;
alter table public.lessons enable row level security;
alter table public.notifications enable row level security;
alter table public.payment_methods enable row level security;
alter table public.guest_content enable row level security;
alter table public.offer_slides enable row level security;
alter table public.app_settings enable row level security;
alter table public.national_exam_results enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'classes',
    'courses',
    'users',
    'lessons',
    'notifications',
    'payment_methods',
    'guest_content',
    'offer_slides',
    'app_settings',
    'national_exam_results'
  ] loop
    execute format('drop policy if exists "epsilon_public_read_%s" on public.%I', table_name, table_name);
    execute format('drop policy if exists "epsilon_public_insert_%s" on public.%I', table_name, table_name);
    execute format('drop policy if exists "epsilon_public_update_%s" on public.%I', table_name, table_name);
    execute format('drop policy if exists "epsilon_public_delete_%s" on public.%I', table_name, table_name);
    execute format('create policy "epsilon_public_read_%s" on public.%I for select using (true)', table_name, table_name);
    execute format('create policy "epsilon_public_insert_%s" on public.%I for insert with check (true)', table_name, table_name);
    execute format('create policy "epsilon_public_update_%s" on public.%I for update using (true) with check (true)', table_name, table_name);
    execute format('create policy "epsilon_public_delete_%s" on public.%I for delete using (true)', table_name, table_name);
  end loop;
end $$;

insert into public.app_settings(key, value) values
  ('paymentNumber', ''),
  ('paymentAmount', ''),
  ('offerTextTitle', ''),
  ('offerTextBody', ''),
  ('offerTextActive', 'true')
on conflict (key) do nothing;

do $$
declare
  default_class_id uuid;
  default_course_id uuid;
begin
  select id into default_class_id
  from public.classes
  order by created_at asc
  limit 1;

  if default_class_id is null then
    insert into public.classes(name, level)
    values ('عام', 'كل المستويات')
    returning id into default_class_id;
  end if;

  select id into default_course_id
  from public.courses
  order by created_at asc
  limit 1;

  if default_course_id is null then
    insert into public.courses(
      title,
      class_id,
      description,
      price,
      subjects,
      subject_details
    )
    values (
      'البكالوريا',
      default_class_id,
      'قسم البكالوريا مع مواد منظمة',
      'غير محدد',
      '["الفيزياء","الكيمياء","الرياضيات","العلوم"]'::jsonb,
      '[{"name":"الفيزياء"},{"name":"الكيمياء"},{"name":"الرياضيات"},{"name":"العلوم"}]'::jsonb
    )
    returning id into default_course_id;
  end if;

  insert into public.users(name, phone, password, role, status, class_id, course_id, subject)
  values
    ('إدارة المدرسة', '34605765', '34605765', 'admin', 'active', default_class_id, default_course_id, null),
    ('الأستاذ', '32324816', '32324816', 'teacher', 'active', default_class_id, default_course_id, 'مادة عامة'),
    ('الطالب', '32164866', '32164866', 'student', 'active', default_class_id, default_course_id, null)
  on conflict (phone) do update set
    name = excluded.name,
    password = excluded.password,
    role = excluded.role,
    status = excluded.status,
    class_id = excluded.class_id,
    course_id = excluded.course_id,
    subject = excluded.subject;
end $$;
