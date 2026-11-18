-- One shared file per student and faculty. Rejected files do not count.
create or replace function public.epsilon_one_file_per_faculty()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1 from public.student_files
    where uploader_id = new.uploader_id
      and lower(faculty) = lower(new.faculty)
      and status <> 'rejected'
  ) then
    raise exception 'لقد شاركت ملفاً لهذه الكلية من قبل. يسمح بمساهمة واحدة لكل كلية.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_epsilon_one_file_per_faculty on public.student_files;
create trigger trg_epsilon_one_file_per_faculty
  before insert on public.student_files
  for each row execute function public.epsilon_one_file_per_faculty();
