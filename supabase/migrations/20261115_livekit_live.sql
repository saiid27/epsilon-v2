-- Epsilon live classes on LiveKit: rooms, answered questions and realtime
-- chat. Sessions are not recorded. Run after 20261112_figma_redesign.sql.

alter table public.live_sessions add column if not exists room_name text not null default '';
alter table public.live_sessions add column if not exists started_at timestamptz;
alter table public.live_sessions add column if not exists ended_at timestamptz;

alter table public.live_messages add column if not exists answered boolean not null default false;

create index if not exists idx_live_messages_session on public.live_messages(session_id, created_at);
create index if not exists idx_live_sessions_teacher on public.live_sessions(teacher_id, starts_at desc);

-- Live chat and session state are pushed to the app with Supabase Realtime.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'live_messages'
  ) then
    alter publication supabase_realtime add table public.live_messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'live_sessions'
  ) then
    alter publication supabase_realtime add table public.live_sessions;
  end if;
end $$;

-- The free plan is live sessions and PDF files only.
update public.plans
   set features = '["البث المباشر المجاني","ملفات PDF مختارة"]'::jsonb
 where code = 'free';
