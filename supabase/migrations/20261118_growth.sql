-- Growth: referral codes and rewards, and the assistant's season bonus.
-- Run after 20261115_livekit_live.sql.

-- Each student gets a short referral code, and may record who invited them.
alter table public.users add column if not exists referral_code text not null default '';
alter table public.users add column if not exists referred_by text not null default '';

-- New students get a random code by default; existing students get one now.
alter table public.users
  alter column referral_code set default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

update public.users
   set referral_code = upper(substr(md5(id::text), 1, 6))
 where referral_code = '';

create unique index if not exists idx_users_referral_code on public.users(referral_code)
  where referral_code <> '';

-- A reward is given once per invited student.
create table if not exists public.referral_rewards (
  referred_id uuid primary key references public.users(id) on delete cascade,
  referrer_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.referral_rewards enable row level security;

-- When an invited student's first subscription becomes active, the inviter
-- gets 5 questions and 1 file added to their assistant credit.
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
  -- Only the first active subscription of this student rewards the inviter.
  insert into public.referral_rewards(referred_id, referrer_id)
  values (new.student_id, inviter)
  on conflict do nothing;
  if not found then
    return new;
  end if;
  insert into public.assistant_credits(user_id, questions, files, refreshed_on)
  values (inviter, 15, 7, current_date)
  on conflict (user_id) do update
    set questions = public.assistant_credits.questions + 5,
        files = public.assistant_credits.files + 1;
  return new;
end;
$$;

drop trigger if exists trg_epsilon_referral_reward on public.subject_subscriptions;
create trigger trg_epsilon_referral_reward
  after update on public.subject_subscriptions
  for each row execute function public.epsilon_referral_reward();

-- Season bonus for the assistant (exam weeks): the daily allowance is
-- multiplied by this factor. Change it in the admin's settings (app_settings).
insert into public.app_settings(key, value)
values ('assistantBonus', '1')
on conflict (key) do nothing;
