-- Token allowance for the assistant, bonus tokens, and the measurement views.
-- Run after 20261118_growth.sql and 20261118_usage_log.sql.

-- A student's plan tier for the assistant (basic, standard, pro). Empty means
-- the default tier from app_settings ('assistantDefaultTier').
alter table public.users add column if not exists assistant_tier text not null default '';

insert into public.app_settings(key, value) values
  ('assistantDefaultTier', 'standard'),
  ('usdToMru', '40')
on conflict (key) do nothing;

-- Bonus tokens granted to a student (referral rewards and manual gifts).
create table if not exists public.assistant_bonus (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  input_tokens int not null default 0,
  output_tokens int not null default 0,
  reason text not null default '',
  created_at timestamptz not null default now()
);
alter table public.assistant_bonus enable row level security;

-- The inviter gets 100 000 input and 10 000 output tokens once per invited
-- student, added to the monthly pool.
create or replace function public.epsilon_referral_reward()
returns trigger
language plpgsql
as $$
declare
  inviter uuid;
begin
  if new.status <> 'active' or old.status = 'active' then
    return new;
  end if;
  select u.id into inviter
    from public.users student
    join public.users u on u.referral_code = student.referred_by
   where student.id = new.student_id
     and u.id <> student.id
   limit 1;
  if inviter is null then
    return new;
  end if;
  insert into public.referral_rewards(referred_id, referrer_id)
  values (new.student_id, inviter)
  on conflict do nothing;
  if not found then
    return new;
  end if;
  insert into public.assistant_bonus(user_id, input_tokens, output_tokens, reason)
  values (inviter, 100000, 10000, 'referral');
  return new;
end;
$$;

-- Measurement, one row per month: revenue from subscriptions, the assistant's
-- real cost, gross profit, and how many students actually use the assistant.
-- Run:  select * from public.epsilon_monthly_metrics;
create or replace view public.epsilon_monthly_metrics as
with rate as (
  select coalesce((select value::numeric from public.app_settings where key = 'usdToMru'), 40) as mru
),
costs as (
  select date_trunc('month', day)::date as month,
         count(*) as answers,
         count(distinct user_id) as ai_users,
         sum(input_tokens + output_tokens) as tokens,
         sum(cost_usd) as cost_usd
  from public.assistant_costs
  group by 1
),
revenue as (
  select date_trunc('month', coalesce(starts_at, created_at))::date as month,
         sum(amount) as revenue_mru,
         count(distinct student_id) as paying_students
  from public.subject_subscriptions
  where status in ('active', 'expired')
  group by 1
)
select coalesce(r.month, c.month) as month,
       coalesce(r.revenue_mru, 0) as revenue_mru,
       coalesce(r.paying_students, 0) as paying_students,
       coalesce(c.answers, 0) as answers,
       coalesce(c.ai_users, 0) as ai_users,
       coalesce(c.tokens, 0) as tokens,
       round(coalesce(c.cost_usd, 0) * (select mru from rate), 0) as ai_cost_mru,
       round(coalesce(r.revenue_mru, 0) * 0.98 - coalesce(c.cost_usd, 0) * (select mru from rate), 0) as gross_profit_mru,
       round(coalesce(c.ai_users, 0)::numeric / nullif(r.paying_students, 0) * 100, 1) as usage_pct,
       round(coalesce(c.answers, 0)::numeric / nullif(c.ai_users, 0), 1) as answers_per_user
from revenue r
full join costs c on c.month = r.month
order by 1 desc;
