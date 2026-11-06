# Live database verification — 2026-11-07

## Project
- Name: Nivora Mumbai
- Project ref: fufjedfplbuzeyriqekc
- Status at verification: ACTIVE_HEALTHY
- PostgreSQL 17.11

## Application schema
| Object | Verified state |
|---|---|
| public.profiles | Present; RLS enabled |
| public.bookings | Present; RLS enabled |
| private.is_nivora_admin() | Present; SECURITY DEFINER; empty search_path |
| public.handle_new_user() | Present; SECURITY DEFINER; empty search_path |

## Policies
- bookings: Admin or assigned vendor view bookings (SELECT)
- bookings: Admin update bookings (UPDATE)
- bookings: Public submit booking (INSERT)
- profiles: Users read own profile (SELECT)

## Important findings
- Both application tables returned 0 rows during verification. This is a row count, not proof that no users exist in Supabase Auth.
- Two auth.users triggers currently invoke public.handle_new_user(). They are functionally redundant because the function uses ON CONFLICT (id) DO NOTHING. Consolidation is recommended, but no live trigger was changed during this baseline capture.
- Security advisor returned zero lint findings at verification.
- Performance advisor reported two INFO-level unused-index notices for bookings_created_idx and bookings_vendor_idx. Keep them until usage can be assessed under real traffic; do not drop them solely on this notice.

## Scope limitation
This is an application-schema snapshot. It intentionally excludes Supabase-managed auth, storage, realtime and vault internals, secrets, and all row data. It is not a physical backup.
