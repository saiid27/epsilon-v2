-- Law and economics are separate faculties; medicine is one faculty with its
-- programmes (general medicine, pharmacy, dentistry) chosen as the track.
delete from public.faculties where name = 'FSJE';

insert into public.faculties(name, label, status) values
  ('LAW', 'كلية القانون', 'approved'),
  ('ECO', 'كلية الاقتصاد', 'approved')
on conflict (name) do nothing;

update public.faculties
   set label = 'كلية الطب'
 where name = 'MED';
