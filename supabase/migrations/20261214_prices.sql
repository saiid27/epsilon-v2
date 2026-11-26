-- The assistant packages move to the database, so the admin sets their prices.
create table if not exists public.assistant_packages (
  code text primary key,
  name text not null,
  tagline text not null default '',
  monthly int not null default 0,
  yearly int not null default 0,
  questions int not null default 0,
  files int not null default 0,
  perks jsonb not null default '[]'::jsonb,
  highlight boolean not null default false,
  sort_order int not null default 0
);
alter table public.assistant_packages enable row level security;
drop policy if exists "epsilon_public_assistant_packages" on public.assistant_packages;
create policy "epsilon_public_assistant_packages" on public.assistant_packages
  for all using (true) with check (true);

insert into public.assistant_packages
  (code, name, tagline, monthly, yearly, questions, files, perks, highlight, sort_order)
values
  ('basic', 'المبتدئ', 'للتعرّف على المساعد', 150, 1500, 3, 1,
   '["كل أوضاع المساعد","الصور وملفات PDF","حفظ الإجابات كملف PDF"]'::jsonb, false, 1),
  ('standard', 'المتميز', 'الأكثر طلباً من الطلاب', 300, 3000, 5, 2,
   '["كل ما في المبتدئ","السيرة الذاتية والرسائل والتقارير","السؤال بالصوت بالعربية والفرنسية","رصيد يتراكم حتى 7 أيام"]'::jsonb, true, 2),
  ('pro', 'الاحترافي', 'للطلاب في الماستر والمشاريع', 450, 4500, 8, 3,
   '["كل ما في المتميز","مذكرة التخرج والبرمجة","ضعف الرصيد اليومي","أولوية في الرد"]'::jsonb, false, 3)
on conflict (code) do nothing;
