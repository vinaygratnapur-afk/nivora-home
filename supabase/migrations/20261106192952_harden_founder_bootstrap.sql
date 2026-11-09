-- Tighten founder bootstrap: use a one-time RLS-protected self-promotion path.
-- The SECURITY DEFINER helper is kept in the non-API-exposed private schema.
drop function if exists public.claim_initial_admin();

create or replace function private.no_nivora_admin_exists()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select not exists (
    select 1 from public.profiles where role = 'admin'
  );
$function$;

revoke all on function private.no_nivora_admin_exists() from public;
grant usage on schema private to authenticated;
grant execute on function private.no_nivora_admin_exists() to authenticated;

drop policy if exists "Founder first-admin bootstrap" on public.profiles;
create policy "Founder first-admin bootstrap"
  on public.profiles
  for update
  to authenticated
  using (
    id = (select auth.uid())
    and role = 'customer'
    and lower(coalesce(auth.jwt() ->> 'email', '')) = 'vinaygratnapur@gmail.com'
    and private.no_nivora_admin_exists()
  )
  with check (
    id = (select auth.uid())
    and role = 'admin'
  );

grant update on public.profiles to authenticated;
