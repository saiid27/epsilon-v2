-- The student's university timetable, and a nightly reminder at 21:00
-- (Mauritania time, UTC+0) listing tomorrow's classes.
-- weekday follows Postgres: 0 = Sunday ... 6 = Saturday.

create table if not exists public.student_timetable (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.users(id) on delete cascade,
  weekday int not null check (weekday between 0 and 6),
  starts_at time not null,
  ends_at time,
  subject_name text not null,
  room text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_student_timetable_day on public.student_timetable(student_id, weekday, starts_at);
alter table public.student_timetable enable row level security;
drop policy if exists "epsilon_public_student_timetable" on public.student_timetable;
create policy "epsilon_public_student_timetable" on public.student_timetable
  for all using (true) with check (true);

create or replace function public.epsilon_notify_timetable_tomorrow()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  tomorrow_dow int := extract(dow from (now() at time zone 'Africa/Nouakchott') + interval '1 day')::int;
  added int;
begin
  with day_classes as (
    select t.student_id,
           string_agg(
             to_char(t.starts_at, 'HH24:MI') || '  ' || t.subject_name
               || case when t.room <> '' then ' (' || t.room || ')' else '' end,
             '  •  ' order by t.starts_at
           ) as lines,
           count(*) as n
    from public.student_timetable t
    join public.users u on u.id = t.student_id and u.status = 'active'
    where t.weekday = tomorrow_dow
    group by t.student_id
  ),
  notes as (
    insert into public.notifications(user_id, kind, title, body)
    select d.student_id, 'timetable',
           'حصصك غداً (' || d.n || ')',
           d.lines
    from day_classes d
    where not exists (
      select 1 from public.notifications n
      where n.user_id = d.student_id
        and n.kind = 'timetable'
        and n.created_at > now() - interval '18 hours'
    )
    returning 1
  )
  select count(*) into added from notes;
  return added;
end;
$$;

-- Every night at 21:00 Mauritania time (21:00 UTC).
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('epsilon-timetable-tomorrow')
    from cron.job where jobname = 'epsilon-timetable-tomorrow';
  perform cron.schedule(
    'epsilon-timetable-tomorrow',
    '0 21 * * *',
    $cron$select public.epsilon_notify_timetable_tomorrow();$cron$
  );
exception when others then
  raise notice 'pg_cron is not available: %', sqlerrm;
end $$;
