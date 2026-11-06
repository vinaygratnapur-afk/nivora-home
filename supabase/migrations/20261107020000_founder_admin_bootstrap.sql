-- Nivora Mumbai: one-time, email-bound founder bootstrap.
-- Only the verified repository owner's connected GitHub email may claim the first admin role.
-- The function becomes ineffective as soon as an admin profile exists.
create or replace function public.claim_initial_admin()
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  caller_id uuid := auth.uid();
  caller_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if caller_id is null then
    raise exception 'Authentication required';
  end if;

  if caller_email <> 'vinaygratnapur@gmail.com' then
    raise exception 'This account is not authorized to initialize Nivora administration';
  end if;

  if exists (select 1 from public.profiles where role = 'admin') then
    raise exception 'Nivora already has an administrator';
  end if;

  insert into public.profiles (id, full_name, role)
  values (caller_id, '', 'customer')
  on conflict (id) do nothing;

  update public.profiles
     set role = 'admin'
   where id = caller_id
     and role = 'customer';

  if not found then
    raise exception 'Unable to initialize administrator profile';
  end if;

  return true;
end;
$function$;

revoke all on function public.claim_initial_admin() from public;
revoke all on function public.claim_initial_admin() from anon;
grant execute on function public.claim_initial_admin() to authenticated;

-- Remove the redundant duplicate auth trigger; retain the original trigger.
drop trigger if exists on_auth_user_created_nivora on auth.users;
