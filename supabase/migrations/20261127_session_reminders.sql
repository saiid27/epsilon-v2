-- Tomorrow's live sessions: each student gets one in-app notification the day
-- before a session they can join (subscribers of the subject, or students who
-- asked for a reminder). Times are shown in Mauritania time (UTC+0).

create table if not exists public.session_reminders_sent (
  session_id uuid not null references public.live_sessions(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  sent_at timestamptz not null default now(),
  primary key (session_id, user_id)
);
alter table public.session_reminders_sent enable row level security;
drop policy if exists "epsilon_public_session_reminders" on public.session_reminders_sent;
create policy "epsilon_public_session_reminders" on public.session_reminders_sent
  for all using (true) with check (true);

create or replace function public.epsilon_notify_tomorrow_sessions()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  tomorrow date := (now() at time zone 'Africa/Nouakchott')::date + 1;
  added int;
begin
  with targets as (
    select distinct s.id as session_id, u.id as user_id, s.title, s.starts_at
    from public.live_sessions s
    join public.users u on u.role = 'student' and u.status = 'active'
    where (s.starts_at at time zone 'Africa/Nouakchott')::date = tomorrow
      and (
        exists (
          select 1 from public.subject_subscriptions sub
          where sub.student_id = u.id
            and sub.subject_id = s.subject_id
            and sub.status = 'active'
            and (sub.expires_at is null or sub.expires_at > now())
        )
        or exists (
          select 1 from public.live_reminders r
          where r.session_id = s.id and r.user_id = u.id
        )
      )
  ),
  fresh as (
    insert into public.session_reminders_sent(session_id, user_id)
    select session_id, user_id from targets
    on conflict do nothing
    returning session_id, user_id
  ),
  notes as (
    insert into public.notifications(user_id, kind, title, body)
    select f.user_id, 'session_tomorrow',
           'حصة غداً: ' || t.title,
           'تبدأ الساعة ' || to_char(t.starts_at at time zone 'Africa/Nouakchott', 'HH24:MI')
             || ' • ادخل من تبويب مباشر'
    from fresh f
    join targets t on t.session_id = f.session_id and t.user_id = f.user_id
    returning 1
  )
  select count(*) into added from notes;
  return added;
end;
$$;

-- Runs every day at 18:00 Mauritania time (18:00 UTC) for the next day's sessions.
-- pg_cron must be enabled in Supabase (Database ← Extensions). If it is not,
-- run `select public.epsilon_notify_tomorrow_sessions();` manually instead.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('epsilon-tomorrow-sessions')
    from cron.job where jobname = 'epsilon-tomorrow-sessions';
  perform cron.schedule(
    'epsilon-tomorrow-sessions',
    '0 18 * * *',
    $cron$select public.epsilon_notify_tomorrow_sessions();$cron$
  );
exception when others then
  raise notice 'pg_cron is not available: %', sqlerrm;
end $$;
