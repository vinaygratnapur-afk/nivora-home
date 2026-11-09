-- Consolidate update policies and optimize the founder bootstrap JWT expression.
create index if not exists partner_applications_reviewed_by_idx
  on public.partner_applications (reviewed_by);

drop policy if exists "Admin update bookings" on public.bookings;
drop policy if exists "Assigned vendor updates job status" on public.bookings;
create policy "Admin or assigned vendor update booking"
  on public.bookings for update to authenticated
  using (
    private.is_nivora_admin()
    or (
      assigned_vendor_id = (select auth.uid())
      and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid()) and p.role = 'vendor'
      )
    )
  )
  with check (
    private.is_nivora_admin()
    or (
      assigned_vendor_id = (select auth.uid())
      and status = any (array['Confirmed','Completed','Cancelled']::text[])
      and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid()) and p.role = 'vendor'
      )
    )
  );

drop policy if exists "Admin manages profiles" on public.profiles;
drop policy if exists "Founder first-admin bootstrap" on public.profiles;
create policy "Admin or founder bootstrap updates profile"
  on public.profiles for update to authenticated
  using (
    private.is_nivora_admin()
    or (
      id = (select auth.uid())
      and role = 'customer'
      and lower(coalesce(((select auth.jwt()) ->> 'email'), '')) = 'vinaygratnapur@gmail.com'
      and (select private.no_nivora_admin_exists())
    )
  )
  with check (
    private.is_nivora_admin()
    or (
      id = (select auth.uid())
      and role = 'admin'
      and lower(coalesce(((select auth.jwt()) ->> 'email'), '')) = 'vinaygratnapur@gmail.com'
    )
  );
