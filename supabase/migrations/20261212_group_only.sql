-- A group-only subscription: the teacher's group, without the lessons and files.
-- The admin sets the group price of each subject.
alter table public.subjects add column if not exists group_price int not null default 0;

alter table public.subject_subscriptions add column if not exists access text not null default 'full';
alter table public.subject_subscriptions drop constraint if exists subject_subscriptions_access_check;
alter table public.subject_subscriptions add constraint subject_subscriptions_access_check
  check (access in ('full', 'groups'));
