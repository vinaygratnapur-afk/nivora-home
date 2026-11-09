-- Remove unnecessary elevated table privileges from client roles.
-- Row-level security does not apply to TRUNCATE, so client roles must never receive it.
REVOKE ALL PRIVILEGES ON TABLE public.partner_applications FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE public.profiles, public.bookings, public.partner_applications FROM anon, authenticated;
