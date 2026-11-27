-- The admin decides whether a session's stream link is shown to students.
alter table public.live_sessions add column if not exists show_link boolean not null default false;
