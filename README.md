# Nivora Mumbai

Repository for the Nivora Mumbai application.

## Database source of truth

- Supabase project: `Nivora Mumbai` (`fufjedfplbuzeyriqekc`)
- PostgreSQL: 17
- Region: `ap-northeast-1`
- Live application tables verified on 2026-11-07: `public.profiles`, `public.bookings`
- RLS is enabled on both application tables.
- The live Supabase migration ledger contained:
  - `20261106185014_initial_schema_baseline_and_security_hardening`
  - `20261106185029_isolate_admin_helper_in_private_schema`
  - `20261106185844_consolidate_booking_select_policies`

## Baseline policy

`supabase/migrations/20261107010000_nivora_live_schema_baseline.sql` records the application-owned schema observed in the live database. It is schema-only and contains no customer, booking, user, credential, or other row data.

Supabase-managed schemas (`auth`, `storage`, `realtime`, `vault`) and platform-managed event triggers are not recreated here. They are managed by Supabase. Do not restore platform internals from this application baseline.

The live database had two equivalent `auth.users` triggers invoking `public.handle_new_user()`; the baseline deliberately avoids creating a further duplicate.

## Important

- This repository snapshot is a baseline of the live application schema, not a database dump.
- It does not contain production data or secrets.
- Do not run this against production as a substitute for a backup.
- Keep future schema changes as new timestamped migrations.
- Before production migration deployment: take a provider backup, review the SQL, test on a staging database, then apply through the normal migration workflow.
