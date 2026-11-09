# Nivora Mumbai

Nivora is a managed Mumbai home-services marketplace. The operating model is coordinator-led: customers request a service, Nivora reviews the request and partner availability, confirms the quotation, and assigns an approved service partner.

## Repository and deployment

- GitHub repository: https://github.com/vinaygratnapur-afk/nivora-home
- Default branch: `main`
- Static frontend: `index.html`
- Deployment: GitHub Pages via `.github/workflows/deploy-pages.yml`
- Supabase project: `Nivora Mumbai` (`fufjedfplbuzeyriqekc`)
- PostgreSQL: 17
- Region: `ap-northeast-1`

## Live application schema

The application-owned public tables are:

- `public.profiles` — user identity and role (`customer`, `admin`, `vendor`)
- `public.bookings` — customer requests, assignment, status, final quote, and commission/payment ledger fields
- `public.partner_applications` — partner onboarding, review status, commission rate, and subscription settings

Row Level Security is enabled on all three tables. Public users can submit a new booking but cannot read booking rows. Customers can track a request only with the high-entropy booking reference and matching mobile number; the tracking RPC returns limited status information and does not reveal address, phone, or notes. Vendors can see only jobs assigned to their own user ID and can update job status only. Database triggers prevent vendors from changing quote or billing fields.

## Implemented pilot workflows

- Mobile-friendly service catalogue and booking enquiry form
- Unique booking reference generation
- Customer booking tracking by reference + phone
- Partner account creation and partner application submission
- Admin partner approval/rejection; approval and role promotion are atomic
- Admin booking review, status changes, and assignment to approved partners
- Partner view of assigned jobs and job status updates
- Final quotation capture
- Commission calculation when a completed job has a final quote and approved assigned partner
- Partner commission-rate and monthly/annual subscription tracking

## Revenue model and payment limitations

The database supports a managed-marketplace commission model and monthly/annual partner subscription records. Commission is calculated as a receivable when a completed job has a final quote. Subscription status and renewal date are managed by the admin.

**No payment gateway is connected.** The current pilot records payment/commission status but does not collect customer payments, charge partner subscriptions, or pay out vendors. Do not represent a payment as collected unless the transaction is verified with the payment provider.

## Migration history

The live Supabase migration ledger currently contains:

- `20261106185014_initial_schema_baseline_and_security_hardening`
- `20261106185029_isolate_admin_helper_in_private_schema`
- `20261106185844_consolidate_booking_select_policies`
- `20261106192838_nivora_live_schema_baseline`
- `20261106192917_founder_admin_bootstrap`
- `20261106192952_harden_founder_bootstrap`
- `20261109061419_marketplace_workflows`
- `20261109061440_atomic_partner_review`
- `20261109061620_harden_public_rpc_and_fix_tracking`
- `20261109061729_commission_and_subscription_ledger`
- `20261109061833_guard_vendor_billing_fields`
- `20261109061858_consolidate_update_policies`

Keep future schema changes as new timestamped migrations under `supabase/migrations/`. The schema baseline in this repository is schema-only and contains no production data. It is not a backup and must not be used as a production restore.

## Production launch checklist

1. Confirm Supabase Auth Site URL and Redirect URLs include the final GitHub Pages URL (and custom domain once configured).
2. Sign in to the Admin tab using the founder email, complete the one-time first-admin activation, then verify the admin dashboard.
3. Create at least one partner test account, submit an application, approve it from Admin, and verify assignment and vendor status updates.
4. Submit a test customer booking and verify reference/phone tracking and admin status updates.
5. Configure a payment provider account and server-side secrets before enabling real payment collection or subscription charging.
6. Add the production domain, privacy notice, terms, cancellation/refund policy, partner agreement, support contact, and operational coverage rules.
7. Run end-to-end tests with test accounts before accepting real customer requests.

## Security notes

- Never put a Supabase service-role key or payment secret in `index.html`.
- The browser may use only the Supabase publishable/anon key.
- Keep RLS enabled; do not make bookings publicly selectable.
- Partner approval is admin-only and uses an atomic database function.
- Customer booking tracking returns a restricted projection only.
- Preserve existing tables and rows when applying future migrations.

### Historical migration markers

The first three migration files are no-op markers because their original SQL predates repository migration control and was not recoverable from the live migration ledger. Their resulting schema/security state is represented by the idempotent live schema baseline that follows. These markers preserve exact applied version ordering without inventing or replaying historical DDL. The remaining migration files contain the SQL for the corresponding applied changes.
