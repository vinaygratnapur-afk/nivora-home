-- Nivora managed-marketplace billing ledger fields.
-- No payment gateway is activated by this migration; this records agreed quotes and receivables.

alter table public.partner_applications
  add column if not exists commission_rate numeric(5,2) not null default 15.00
    check (commission_rate >= 0 and commission_rate <= 100),
  add column if not exists subscription_plan text not null default 'pilot'
    check (subscription_plan = any (array['pilot','monthly','annual']::text[])),
  add column if not exists subscription_amount integer not null default 0
    check (subscription_amount >= 0),
  add column if not exists subscription_status text not null default 'trial'
    check (subscription_status = any (array['trial','active','past_due','cancelled']::text[])),
  add column if not exists subscription_renewal_date date;

alter table public.bookings
  add column if not exists final_quote integer
    check (final_quote is null or final_quote >= 0),
  add column if not exists commission_amount integer not null default 0
    check (commission_amount >= 0),
  add column if not exists commission_status text not null default 'not_due'
    check (commission_status = any (array['not_due','due','paid','waived']::text[])),
  add column if not exists payment_status text not null default 'not_collected'
    check (payment_status = any (array['not_collected','paid','refunded','waived']::text[]));

revoke update on public.bookings from authenticated;
grant update (status, assigned_vendor_id, final_quote, commission_status, payment_status) on public.bookings to authenticated;

create or replace function private.calculate_nivora_commission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_rate numeric(5,2);
begin
  if new.status = 'Completed' and new.final_quote is not null and new.assigned_vendor_id is not null then
    select pa.commission_rate into v_rate
    from public.partner_applications pa
    where pa.user_id = new.assigned_vendor_id
      and pa.status = 'approved';

    new.commission_amount := round(new.final_quote * coalesce(v_rate, 0) / 100.0)::integer;
    if new.commission_status = 'not_due' then
      new.commission_status := 'due';
    end if;
  elsif new.status <> 'Completed' then
    new.commission_amount := 0;
    new.commission_status := 'not_due';
  end if;
  return new;
end;
$function$;

revoke all on function private.calculate_nivora_commission() from public;

drop trigger if exists calculate_nivora_commission_before_update on public.bookings;
create trigger calculate_nivora_commission_before_update
before update of status, final_quote, assigned_vendor_id
on public.bookings
for each row execute function private.calculate_nivora_commission();
