-- Two section packages, each one subscription with all its features:
-- pkg_groups (PDF, live, groups) and pkg_videos (recorded videos, PDF).
alter table public.section_feature_subscriptions
  drop constraint if exists section_feature_subscriptions_feature_check;
alter table public.section_feature_subscriptions
  add constraint section_feature_subscriptions_feature_check
  check (feature in ('groups', 'videos', 'live', 'assistant', 'pdf', 'pkg_groups', 'pkg_videos'));

alter table public.courses add column if not exists pkg_groups_price int not null default 0;
alter table public.courses add column if not exists pkg_videos_price int not null default 0;

-- The admin reviews section subscriptions: students see the requests they sent.
alter table public.section_feature_subscriptions add column if not exists reviewed_at timestamptz;
