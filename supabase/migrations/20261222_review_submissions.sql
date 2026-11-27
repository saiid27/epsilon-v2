-- A student's own review of the app: hidden until the admin accepts it.
alter table public.app_reviews add column if not exists user_id uuid references public.users(id) on delete set null;
