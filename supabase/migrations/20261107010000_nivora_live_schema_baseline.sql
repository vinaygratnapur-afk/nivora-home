-- Nivora Mumbai: application-schema baseline captured from live Supabase.
-- Project: fufjedfplbuzeyriqekc | PostgreSQL 17
-- Captured: 2026-11-07
-- Scope: application-owned public schema + private helper schema.
-- Supabase-managed auth/storage/realtime schemas and platform event triggers are intentionally excluded.
-- This file describes schema only; it contains NO application data.
-- Review before applying to any database. It is designed to be re-runnable.

create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'customer'
    check (role = any (array['customer','admin','vendor']::text[])),
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  customer_name text not null,
  phone text not null,
  service_id text not null,
  service_name text not null,
  indicative_price integer not null default 0,
  area text not null,
  service_address text not null,
  preferred_date date not null,
  preferred_slot text not null,
  details text,
  status text not null default 'New'
    check (status = any (array['New','Contacted','Quoted','Confirmed','Completed','Cancelled']::text[])),
  assigned_vendor_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists bookings_created_idx
  on public.bookings using btree (created_at desc);
create index if not exists bookings_vendor_idx
  on public.bookings using btree (assigned_vendor_id);

create or replace function private.is_nivora_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$function$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;

alter table public.profiles enable row level security;
alter table public.bookings enable row level security;

do $policies$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='bookings' and policyname='Admin or assigned vendor view bookings') then
    create policy "Admin or assigned vendor view bookings"
      on public.bookings for select to authenticated
      using (
        private.is_nivora_admin()
        or (
          assigned_vendor_id = (select auth.uid())
          and exists (
            select 1 from public.profiles
            where profiles.id = (select auth.uid())
              and profiles.role = 'vendor'
          )
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='bookings' and policyname='Admin update bookings') then
    create policy "Admin update bookings"
      on public.bookings for update to authenticated
      using (private.is_nivora_admin())
      with check (private.is_nivora_admin());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='bookings' and policyname='Public submit booking') then
    create policy "Public submit booking"
      on public.bookings for insert to anon, authenticated
      with check (
        status = 'New'
        and assigned_vendor_id is null
        and char_length(customer_name) between 2 and 80
        and phone ~ '^[6-9][0-9]{9}$'
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='Users read own profile') then
    create policy "Users read own profile"
      on public.profiles for select to authenticated
      using (id = (select auth.uid()));
  end if;
end
$policies$;

grant select on public.profiles to authenticated;
grant select, update on public.bookings to authenticated;
grant insert on public.bookings to anon, authenticated;

-- Live database currently has two equivalent auth.users triggers calling
-- public.handle_new_user(). This baseline intentionally creates one canonical
-- trigger only when no trigger using this function exists, avoiding duplicates.
do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where not t.tgisinternal
      and n.nspname = 'auth'
      and c.relname = 'users'
      and p.proname = 'handle_new_user'
  ) then
    execute 'create trigger on_auth_user_created_nivora after insert on auth.users for each row execute function public.handle_new_user()';
  end if;
end
$trigger$;
