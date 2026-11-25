-- What a section offers, written by the admin and shown to new subscribers.
alter table public.courses add column if not exists features jsonb not null default '[]'::jsonb;
alter table public.courses add column if not exists bundle_price int not null default 0;
alter table public.courses add column if not exists description text not null default '';
