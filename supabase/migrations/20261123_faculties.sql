-- Faculties offered when a student uploads a file. The known faculties are
-- approved from the start; a faculty a student adds waits for the
-- administration's approval, then joins the list for everyone.
create table if not exists public.faculties (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  label text not null default '',
  status text not null default 'approved' check (status in ('pending', 'approved', 'rejected')),
  suggested_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.faculties enable row level security;
drop policy if exists "epsilon_public_read_faculties" on public.faculties;
drop policy if exists "epsilon_public_insert_faculties" on public.faculties;
drop policy if exists "epsilon_public_update_faculties" on public.faculties;
drop policy if exists "epsilon_public_delete_faculties" on public.faculties;
create policy "epsilon_public_read_faculties" on public.faculties for select using (true);
create policy "epsilon_public_insert_faculties" on public.faculties for insert with check (true);
create policy "epsilon_public_update_faculties" on public.faculties for update using (true) with check (true);
create policy "epsilon_public_delete_faculties" on public.faculties for delete using (true);

insert into public.faculties(name, label, status) values
  ('FST', 'كلية العلوم والتقنيات', 'approved'),
  ('FSJE', 'كلية العلوم القانونية والاقتصادية', 'approved'),
  ('FLSH', 'كلية الآداب والعلوم الإنسانية', 'approved'),
  ('MED', 'كلية الطب', 'approved')
on conflict (name) do nothing;
