-- A subject can have several groups. The admin and the teacher add and name
-- them; the admin sets each group's price. A student opens a group by paying
-- its subscription.
alter table public.chat_groups drop constraint if exists chat_groups_subject_id_key;
create index if not exists idx_chat_groups_subject on public.chat_groups (subject_id);

alter table public.chat_groups add column if not exists name text not null default '';
alter table public.chat_groups add column if not exists price int not null default 0;
alter table public.chat_groups add column if not exists active boolean not null default true;
alter table public.chat_groups add column if not exists created_by uuid references public.users(id) on delete set null;

-- The groups that exist today take the subject's name and group price.
update public.chat_groups g
   set name = s.name, price = s.group_price
  from public.subjects s
 where s.id = g.subject_id and g.name = '';

-- A subscription to one group.
create table if not exists public.group_subscriptions (
  id uuid primary key default gen_random_uuid(),
  request_ref text not null default ('EPS-' || to_char(now(), 'YYMMDD') || lpad((floor(random() * 1000))::int::text, 3, '0')),
  student_id uuid not null references public.users(id) on delete cascade,
  group_id uuid not null references public.chat_groups(id) on delete cascade,
  amount int not null default 0,
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  receipt_url text not null default '',
  transaction_ref text not null default '',
  status text not null default 'pending' check (status in ('pending', 'active', 'expired', 'rejected')),
  rejection_reason text not null default '',
  starts_at timestamptz,
  expires_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_group_subscriptions_student on public.group_subscriptions (student_id, group_id);
alter table public.group_subscriptions enable row level security;
drop policy if exists "epsilon_public_group_subscriptions" on public.group_subscriptions;
create policy "epsilon_public_group_subscriptions" on public.group_subscriptions
  for all using (true) with check (true);

-- Students who bought the old subject-level groups keep access to that
-- subject's groups.
insert into public.group_subscriptions
  (student_id, group_id, amount, status, starts_at, expires_at, transaction_ref, reviewed_at)
select s.student_id, g.id, s.amount, 'active', s.starts_at, s.expires_at, 'MIGRATED', s.reviewed_at
  from public.subject_subscriptions s
  join public.chat_groups g on g.subject_id = s.subject_id
 where s.access = 'groups' and s.status = 'active'
   and not exists (
     select 1 from public.group_subscriptions x
      where x.student_id = s.student_id and x.group_id = g.id
   );
