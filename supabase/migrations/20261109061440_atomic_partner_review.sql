-- Atomic admin review for partner applications.
create or replace function public.review_partner_application(
  p_application_id uuid,
  p_decision text,
  p_admin_notes text default null
)
returns boolean
language plpgsql
security definer
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

revoke all on function public.review_partner_application(uuid,text,text) from public;
revoke all on function public.review_partner_application(uuid,text,text) from anon;
grant execute on function public.review_partner_application(uuid,text,text) to authenticated;
