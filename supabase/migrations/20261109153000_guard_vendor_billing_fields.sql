-- Vendors may change only their assigned job status, never quote or billing fields.
create or replace function private.guard_nivora_vendor_booking_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
begin
  select p.role into v_role
  from public.profiles p
  where p.id = (select auth.uid());

  if v_role = 'vendor' then
    if new.assigned_vendor_id is distinct from old.assigned_vendor_id
       or new.final_quote is distinct from old.final_quote
       or new.commission_amount is distinct from old.commission_amount
       or new.commission_status is distinct from old.commission_status
       or new.payment_status is distinct from old.payment_status then
      raise exception 'Partners may update job status only';
    end if;
    if new.status not in ('Confirmed','Completed','Cancelled') then
      raise exception 'Invalid partner job status';
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function private.guard_nivora_vendor_booking_update() from public;

drop trigger if exists a_guard_nivora_vendor_booking_update on public.bookings;
create trigger a_guard_nivora_vendor_booking_update
before update on public.bookings
for each row execute function private.guard_nivora_vendor_booking_update();
