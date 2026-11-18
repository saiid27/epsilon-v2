-- The free plan includes a small assistant allowance (about 3 answers a day).
-- Run after 20261120_student_files.sql.
update public.plans
   set features = '["البث المباشر المجاني","ملفات PDF مختارة","المساعد: حوالي 3 أسئلة يومياً"]'::jsonb
 where code = 'free';
