-- Epsilon: data needed by the Figma redesign.
-- Safe to run more than once in the Supabase SQL editor (after schema.sql).
--
-- Adds: subjects catalog, per-subject subscriptions, plans, teacher/student
-- profile fields, lesson extras and progress, PDF resources, live sessions
-- (with chat and reminders), quizzes (questions, attempts, XP and weekly
-- leaderboard), announcements, per-user notifications and assistant usage.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Users: student study profile, gamification and teacher profile fields
-- ---------------------------------------------------------------------------
alter table public.users add column if not exists university text not null default '';
alter table public.users add column if not exists faculty text not null default '';
alter table public.users add column if not exists track text not null default '';
alter table public.users add column if not exists level text not null default '';
alter table public.users add column if not exists avatar_url text not null default '';
alter table public.users add column if not exists xp int not null default 0;
alter table public.users add column if not exists streak_days int not null default 0;
alter table public.users add column if not exists last_activity_date date;
alter table public.users add column if not exists specialty text not null default '';
alter table public.users add column if not exists bio text not null default '';
alter table public.users add column if not exists years_experience int not null default 0;
alter table public.users add column if not exists rating numeric(2, 1) not null default 0;
alter table public.users add column if not exists profile_completed boolean not null default false;

-- ---------------------------------------------------------------------------
-- Subjects catalog (one row per subject a student can subscribe to)
-- ---------------------------------------------------------------------------
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references public.courses(id) on delete set null,
  name text not null,
  icon text not null default '∑',
  color text not null default '#DBEAFE',
  faculty text not null default '',
  level text not null default '',
  description text not null default '',
  monthly_price int not null default 0,
  discount int not null default 0,
  teacher_id uuid references public.users(id) on delete set null,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.plans (
  code text primary key,
  title text not null,
  subtitle text not null default '',
  badge text not null default '',
  months int not null default 1,
  discount_percent int not null default 0,
  is_free boolean not null default false,
  features jsonb not null default '[]'::jsonb,
  sort_order int not null default 0
);

insert into public.plans(code, title, subtitle, badge, months, discount_percent, is_free, features, sort_order) values
  ('free', 'الخطة المجانية', 'دائماً', 'للجميع', 0, 0, true,
   '["ملفات PDF محددة","تمارين أسبوعية","شروحات قصيرة مجانية"]'::jsonb, 0),
  ('monthly', 'الخطة الشهرية', 'شهر واحد', 'مرنة', 1, 0, false,
   '["جميع الدروس المسجلة","الاختبارات والمسابقات","البث المباشر للمادة"]'::jsonb, 1),
  ('semester', 'الخطة الفصلية', '4 أشهر', 'الأكثر توفيراً', 4, 20, false,
   '["كل مزايا الخطة الشهرية","توفير 20% من السعر","أولوية في دعم الأساتذة"]'::jsonb, 2)
on conflict (code) do nothing;

create table if not exists public.subject_subscriptions (
  id uuid primary key default gen_random_uuid(),
  request_ref text not null default ('EPS-' || to_char(now(), 'YYMMDD') || lpad((floor(random() * 1000))::int::text, 3, '0')),
  student_id uuid not null references public.users(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  plan_code text not null default 'monthly' references public.plans(code),
  amount int not null default 0,
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  receipt_url text not null default '',
  transaction_ref text not null default '',
  status text not null default 'pending' check (status in ('pending', 'active', 'expired', 'rejected')),
  rejection_reason text not null default '',
  starts_at timestamptz,
  expires_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Lessons: link to subjects, extra content and progress
-- ---------------------------------------------------------------------------
alter table public.lessons add column if not exists subject_id uuid references public.subjects(id) on delete cascade;
alter table public.lessons add column if not exists unit text not null default '';
alter table public.lessons add column if not exists duration text not null default '';
alter table public.lessons add column if not exists pdf_url text not null default '';
alter table public.lessons add column if not exists is_free boolean not null default false;
alter table public.lessons add column if not exists description text not null default '';
alter table public.lessons add column if not exists key_idea text not null default '';
alter table public.lessons add column if not exists example text not null default '';
alter table public.lessons add column if not exists sort_order int not null default 0;

create table if not exists public.lesson_progress (
  student_id uuid not null references public.users(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  completed boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (student_id, lesson_id)
);

create table if not exists public.lesson_exercises (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  question text not null,
  illustration text not null default '',
  solution_steps jsonb not null default '[]'::jsonb,
  is_free boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.pdf_resources (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text not null,
  url text not null default '',
  page_count int not null default 0,
  size_text text not null default '',
  is_free boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Live sessions
-- ---------------------------------------------------------------------------
create table if not exists public.live_sessions (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  teacher_id uuid references public.users(id) on delete set null,
  title text not null,
  starts_at timestamptz not null,
  duration_minutes int not null default 60,
  live_url text not null default '',
  recording_url text not null default '',
  is_free boolean not null default false,
  is_live boolean not null default false,
  attendees_count int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.live_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.live_sessions(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  user_name text not null default '',
  is_teacher boolean not null default false,
  is_question boolean not null default false,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.live_reminders (
  session_id uuid not null references public.live_sessions(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (session_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Quizzes, attempts and leaderboard
-- ---------------------------------------------------------------------------
create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text not null,
  kind text not null default 'subject' check (kind in ('daily', 'subject', 'quick')),
  xp_reward int not null default 50,
  time_limit_seconds int not null default 300,
  question_seconds int not null default 30,
  is_free boolean not null default false,
  active boolean not null default true,
  publish_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  prompt text not null,
  formula text not null default '',
  options jsonb not null default '[]'::jsonb,
  correct_index int not null default 0,
  explanation text not null default '',
  sort_order int not null default 0
);

create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  student_id uuid not null references public.users(id) on delete cascade,
  correct_count int not null default 0,
  total int not null default 0,
  xp_earned int not null default 0,
  duration_seconds int not null default 0,
  answers jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create or replace view public.leaderboard_weekly as
  select u.id as student_id,
         u.name,
         u.avatar_url,
         coalesce(sum(a.xp_earned), 0)::int as xp
  from public.users u
  left join public.quiz_attempts a
    on a.student_id = u.id
   and a.created_at >= date_trunc('week', now())
  where u.role = 'student'
  group by u.id, u.name, u.avatar_url;

create or replace view public.leaderboard_all_time as
  select u.id as student_id, u.name, u.avatar_url, u.xp
  from public.users u
  where u.role = 'student';

create or replace view public.leaderboard_by_subject as
  select q.subject_id,
         u.id as student_id,
         u.name,
         u.avatar_url,
         coalesce(sum(a.xp_earned), 0)::int as xp
  from public.quiz_attempts a
  join public.quizzes q on q.id = a.quiz_id
  join public.users u on u.id = a.student_id
  where q.subject_id is not null
  group by q.subject_id, u.id, u.name, u.avatar_url;

-- Award XP and keep the daily streak when an attempt is recorded.
create or replace function public.epsilon_after_quiz_attempt()
returns trigger
language plpgsql
as $$
declare
  last_day date;
begin
  select last_activity_date into last_day from public.users where id = new.student_id;
  update public.users
     set xp = xp + new.xp_earned,
         streak_days = case
           when last_day = current_date then streak_days
           when last_day = current_date - 1 then streak_days + 1
           else 1
         end,
         last_activity_date = current_date
   where id = new.student_id;
  return new;
end;
$$;

drop trigger if exists trg_epsilon_after_quiz_attempt on public.quiz_attempts;
create trigger trg_epsilon_after_quiz_attempt
  after insert on public.quiz_attempts
  for each row execute function public.epsilon_after_quiz_attempt();

-- ---------------------------------------------------------------------------
-- Announcements, per-user notifications, assistant usage
-- ---------------------------------------------------------------------------
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.notifications add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.notifications add column if not exists kind text not null default 'general';

create table if not exists public.notification_reads (
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (notification_id, user_id)
);

create table if not exists public.assistant_usage (
  user_id uuid not null references public.users(id) on delete cascade,
  day date not null default current_date,
  questions int not null default 0,
  primary key (user_id, day)
);

-- Notify the student when a subscription is reviewed.
create or replace function public.epsilon_after_subscription_review()
returns trigger
language plpgsql
as $$
declare
  subject_name text;
begin
  if new.status = old.status then
    return new;
  end if;
  select name into subject_name from public.subjects where id = new.subject_id;
  if new.status = 'active' then
    insert into public.notifications(user_id, kind, title, body)
    values (new.student_id, 'subscription_active', 'تم تفعيل اشتراكك',
            'يمكنك الآن الوصول إلى جميع الدروس والجلسات في ' || coalesce(subject_name, 'المادة') || '.');
  elsif new.status = 'rejected' then
    insert into public.notifications(user_id, kind, title, body)
    values (new.student_id, 'subscription_rejected', 'تم رفض وصل ' || coalesce(subject_name, 'المادة'),
            coalesce(nullif(new.rejection_reason, ''), 'الوصل غير واضح') || ' • اضغط لإعادة رفع الوصل');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_epsilon_after_subscription_review on public.subject_subscriptions;
create trigger trg_epsilon_after_subscription_review
  after update on public.subject_subscriptions
  for each row execute function public.epsilon_after_subscription_review();

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_subjects_active on public.subjects(is_active, sort_order);
create index if not exists idx_subscriptions_student on public.subject_subscriptions(student_id, created_at desc);
create index if not exists idx_subscriptions_status on public.subject_subscriptions(status, created_at desc);
create index if not exists idx_lessons_subject on public.lessons(subject_id, sort_order);
create index if not exists idx_live_sessions_start on public.live_sessions(starts_at);
create index if not exists idx_live_messages_session on public.live_messages(session_id, created_at);
create index if not exists idx_quiz_attempts_student on public.quiz_attempts(student_id, created_at desc);
create index if not exists idx_quiz_attempts_week on public.quiz_attempts(created_at);
create index if not exists idx_notifications_user on public.notifications(user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Row level security: same access model as schema.sql (app uses anon key)
-- ---------------------------------------------------------------------------
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'subjects', 'plans', 'subject_subscriptions', 'lesson_progress',
    'lesson_exercises', 'pdf_resources', 'live_sessions', 'live_messages',
    'live_reminders', 'quizzes', 'quiz_questions', 'quiz_attempts',
    'announcements', 'notification_reads', 'assistant_usage'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
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

grant select on public.leaderboard_weekly to anon, authenticated;
grant select on public.leaderboard_all_time to anon, authenticated;
grant select on public.leaderboard_by_subject to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Data migration: create subjects from existing courses and keep current
-- students' access as active subscriptions.
-- ---------------------------------------------------------------------------
insert into public.subjects(course_id, name, monthly_price, sort_order)
select c.id,
       s.value #>> '{}',
       coalesce(nullif(regexp_replace(coalesce(d.detail ->> 'price', ''), '[^0-9]', '', 'g'), '')::int, 0),
       s.ordinality::int
from public.courses c
cross join lateral jsonb_array_elements(c.subjects) with ordinality as s(value, ordinality)
left join lateral (
  select detail
  from jsonb_array_elements(c.subject_details) as detail
  where detail ->> 'name' = s.value #>> '{}'
  limit 1
) d on true
where not exists (
  select 1 from public.subjects x
  where x.course_id = c.id and x.name = s.value #>> '{}'
);

update public.lessons l
   set subject_id = s.id
  from public.subjects s
 where l.subject_id is null
   and s.course_id = l.course_id
   and s.name = l.subject;

insert into public.subject_subscriptions(student_id, subject_id, plan_code, status, starts_at, expires_at, reviewed_at)
select u.id, s.id, 'monthly', 'active', u.created_at, u.subscription_expires_at, now()
from public.users u
join public.subjects s on s.course_id = u.course_id
where u.role = 'student'
  and u.status = 'active'
  and (
    jsonb_array_length(u.selected_subjects) = 0
    or u.selected_subjects ? s.name
  )
  and not exists (
    select 1 from public.subject_subscriptions x
    where x.student_id = u.id and x.subject_id = s.id
  );
