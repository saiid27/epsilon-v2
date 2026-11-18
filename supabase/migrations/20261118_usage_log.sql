-- Assistant cost log: one row per answer, with tokens and estimated cost,
-- so the real cost per student and per package can be measured.
create table if not exists public.assistant_costs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  day date not null default current_date,
  kind text not null check (kind in ('question', 'file')),
  model text not null default '',
  input_tokens int not null default 0,
  output_tokens int not null default 0,
  cost_usd numeric(10, 6) not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_assistant_costs_day on public.assistant_costs(day);
create index if not exists idx_assistant_costs_user on public.assistant_costs(user_id, day);
alter table public.assistant_costs enable row level security;

-- Cost per student for a month (USD), most expensive first.
-- Run in the SQL Editor:  select * from public.assistant_cost_by_student;
create or replace view public.assistant_cost_by_student as
  select user_id,
         date_trunc('month', day)::date as month,
         count(*) as answers,
         sum(input_tokens) as input_tokens,
         sum(output_tokens) as output_tokens,
         round(sum(cost_usd), 4) as cost_usd
  from public.assistant_costs
  group by user_id, date_trunc('month', day)
  order by cost_usd desc;
