-- Correct phone normalization and keep exposed RPC wrappers invoker-secured.
create or replace function private.track_nivora_booking(p_reference text, p_phone text)
returns table (
  reference text,
  service_name text,
  area text,
  preferred_date date,
  preferred_slot text,
  status text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select b.reference, b.service_name, b.area, b.preferred_date,
         b.preferred_slot, b.status, b.created_at
  from public.bookings b
  where upper(btrim(b.reference)) = upper(btrim(p_reference))
    and regexp_replace(b.phone, '[^0-9]', '', 'g') = regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
  limit 1;
$function$;

revoke all on function private.track_nivora_booking(text,text) from public;
grant usage on schema private to anon, authenticated;
grant execute on function private.track_nivora_booking(text,text) to anon, authenticated;

create or replace function public.track_nivora_booking(p_reference text, p_phone text)
returns table (
  reference text,
  service_name text,
  area text,
  preferred_date date,
  preferred_slot text,
  status text,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select * from private.track_nivora_booking(p_reference, p_phone);
$function$;

revoke all on function public.track_nivora_booking(text,text) from public;
grant execute on function public.track_nivora_booking(text,text) to anon, authenticated;

create or replace function public.review_partner_application(
  p_application_id uuid,
  p_decision text,
  p_admin_notes text default null
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid;
begin
  if not private.is_nivora_admin() then
    raise exception 'Administrator access required';
  end if;
  if p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select user_id into v_user_id
  from public.partner_applications
  where id = p_application_id
  for update;

  if v_user_id is null then
    raise exception 'Partner application not found';
  end if;

  update public.profiles
     set role = case when p_decision = 'approved' then 'vendor' else 'customer' end
   where id = v_user_id;

  update public.partner_applications
     set status = p_decision,
         admin_notes = nullif(btrim(coalesce(p_admin_notes,'')), ''),
         reviewed_by = (select auth.uid()),
         reviewed_at = now(),
         updated_at = now()
   where id = p_application_id;

  return true;
end;
$function$;
