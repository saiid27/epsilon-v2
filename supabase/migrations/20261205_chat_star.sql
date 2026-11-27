-- A starred group is shown first in the students' chat list (the teacher's
-- important group, for new subscribers to see at once).
alter table public.chat_groups add column if not exists starred boolean not null default false;
