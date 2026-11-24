-- Monthly prices: each subject group is 2 000 MRU a month, and a whole section
-- (all its subjects) is 10 000 MRU a month. A monthly plan lasts one month.
alter table public.courses add column if not exists bundle_price int not null default 0;

update public.subjects set monthly_price = 2000;
update public.courses set bundle_price = 10000;

insert into public.plans (code, title, subtitle, badge, months, discount_percent, is_free, features, sort_order, active)
values ('monthly', 'الاشتراك الشهري', 'شهر واحد', 'شهري', 1, 0, false,
        '["جميع الدروس والشروحات","البث المباشر للمادة","التمارين والاختبارات","مجموعة المادة"]'::jsonb, 0, true)
on conflict (code) do update set active = true, months = 1, discount_percent = 0;
