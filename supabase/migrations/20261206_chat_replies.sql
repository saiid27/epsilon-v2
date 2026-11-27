-- Replies: a message can quote an earlier message of the same group.
alter table public.chat_messages add column if not exists reply_to uuid references public.chat_messages(id) on delete set null;
