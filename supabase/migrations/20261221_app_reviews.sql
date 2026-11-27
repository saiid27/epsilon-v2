-- Student reviews shown on the first screen, before sign-up. The admin decides
-- which ones are visible.
create table if not exists public.app_reviews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text not null default '',
  text text not null,
  rating int not null default 5 check (rating between 1 and 5),
  is_visible boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.app_reviews enable row level security;
drop policy if exists "epsilon_public_app_reviews" on public.app_reviews;
create policy "epsilon_public_app_reviews" on public.app_reviews
  for all using (true) with check (true);
