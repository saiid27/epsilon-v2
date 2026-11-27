-- A pinned message: the teacher pins an important message at the top of the group.
alter table public.chat_groups add column if not exists pinned_message_id uuid references public.chat_messages(id) on delete set null;
