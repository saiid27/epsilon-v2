-- The device token of each user, so the server can send push notifications.
alter table public.users add column if not exists push_token text not null default '';
