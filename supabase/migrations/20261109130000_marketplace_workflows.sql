-- Nivora Mumbai: additive marketplace workflows.
-- Safe rollout: preserves existing profiles/bookings rows and all current columns.
-- Adds partner applications, admin approval, vendor job status updates, and guest booking tracking.

create table if not exists public.partner_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  business_name text not null check (char_length(business_name) between 2 and 120),
  contact_name text not null check (char_length(contact_name) between 2 and 80),
  phone text not null check (phone ~ '^[6-9][0-9]{9}$'),
  services text[] not null default '{}',
  service_areas text[] not null default '{}',
  years_experience integer not null default 0 check (years_experience between 0 and 60),
  notes text,
  status text not null default 'pending'
    check (status = any (array['pending','approved','rejected']::text[])),
  admin_notes text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists partner_applications_status_created_idx
  on public.partner_applications (status, created_at desc);

alter table public.partner_applications enable row level security;

drop policy if exists "Partner reads own application or admin reads all" on public.partner_applications;
create policy "Partner reads own application or admin reads all"
  on public.partner_applications for select to authenticated
  using (user_id = (select auth.uid()) or private.is_nivora_admin());

drop policy if exists "Partner submits own application" on public.partner_applications;
create policy "Partner submits own application"
  on public.partner_applications for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'pending'
    and reviewed_by is null
    and reviewed_at is null
  );

drop policy if exists "Admin reviews partner applications" on public.partner_applications;
create policy "Admin reviews partner applications"
  on public.partner_applications for update to authenticated
  using (private.is_nivora_admin())
  with check (private.is_nivora_admin());

grant select, insert, update on public.partner_applications to authenticated;

-- Admins can approve partner roles; ordinary users cannot promote themselves.
drop policy if exists "Admin manages profiles" on public.profiles;
create policy "Admin manages profiles"
  on public.profiles for update to authenticated
  using (private.is_nivora_admin())
  with check (private.is_nivora_admin());

-- Restrict booking updates to the two fields used by the admin/vendor workflows.
revoke update on public.bookings from authenticated;
grant update (status, assigned_vendor_id) on public.bookings to authenticated;

drop policy if exists "Admin update bookings" on public.bookings;
create policy "Admin update bookings"
  on public.bookings for update to authenticated
  using (private.is_nivora_admin())
  with check (private.is_nivora_admin());

drop policy if exists "Assigned vendor updates job status" on public.bookings;
create policy "Assigned vendor updates job status"
  on public.bookings for update to authenticated
  using (
    assigned_vendor_id = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'vendor'
    )
  )
  with check (
    assigned_vendor_id = (select auth.uid())
    and status = any (array['Confirmed','Completed','Cancelled']::text[])
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'vendor'
    )
  );

-- Guest customers can track a booking using its high-entropy reference plus phone.
-- Only non-sensitive status/slot details are returned; address, phone and notes are never exposed.
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
security definer
set search_path = ''
as $function$
  select b.reference, b.service_name, b.area, b.preferred_date,
         b.preferred_slot, b.status, b.created_at
  from public.bookings b
  where upper(btrim(b.reference)) = upper(btrim(p_reference))
    and regexp_replace(b.phone, '\\D', '', 'g') = regexp_replace(coalesce(p_phone, ''), '\\D', '', 'g')
  limit 1;
$function$;

revoke all on function public.track_nivora_booking(text, text) from public;
grant execute on function public.track_nivora_booking(text, text) to anon, authenticated;

-- Avoid per-row JWT/admin helper evaluation in the founder bootstrap policy.
drop policy if exists "Founder first-admin bootstrap" on public.profiles;
create policy "Founder first-admin bootstrap"
  on public.profiles for update to authenticated
  using (
    id = (select auth.uid())
    and role = 'customer'
    and lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'vinaygratnapur@gmail.com'
    and (select private.no_nivora_admin_exists())
  )
  with check (
    id = (select auth.uid())
    and role = 'admin'
  );
