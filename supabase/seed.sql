-- ONLY for the disposable local project described in supabase/README.md.
-- Eight synthetic accounts: all seven roles, two independent customers.
-- No usable password is stored in source or printed. Each account receives a
-- random password hash; actual login/onboarding is not part of Phase 3.
begin;

create temporary table phase3_seed_users (
  id uuid primary key,
  role public.app_role,
  name text,
  email text
) on commit drop;

insert into phase3_seed_users (id, role, name, email) values
  ('30000000-0000-4000-8000-000000000001', 'customer', 'Sentetik Müşteri A', 'customer.a@peksen.invalid'),
  ('30000000-0000-4000-8000-000000000002', 'sales_operator', 'Sentetik Saha Satış', 'sales@peksen.invalid'),
  ('30000000-0000-4000-8000-000000000003', 'warehouse', 'Sentetik Depo', 'warehouse@peksen.invalid'),
  ('30000000-0000-4000-8000-000000000004', 'accounting', 'Sentetik Muhasebe', 'accounting@peksen.invalid'),
  ('30000000-0000-4000-8000-000000000005', 'driver', 'Sentetik Şoför', 'driver@peksen.invalid'),
  ('30000000-0000-4000-8000-000000000006', 'manager', 'Sentetik Yönetici', 'manager@peksen.invalid'),
  ('30000000-0000-4000-8000-000000000007', 'owner', 'Sentetik İşletme Sahibi', 'owner@peksen.invalid'),
  ('30000000-0000-4000-8000-000000000008', 'customer', 'Sentetik Müşteri B', 'customer.b@peksen.invalid');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000'::uuid, id,
  'authenticated', 'authenticated', email,
  extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('name', name), now(), now(), '', '', '', ''
from phase3_seed_users;

insert into auth.identities (
  id, provider_id, user_id, identity_data, provider, created_at, updated_at
)
select id, id::text, id,
  jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true),
  'email', now(), now()
from phase3_seed_users;

insert into public.profiles (id, role, name, email, active)
select id, role, name, email, true from phase3_seed_users;

insert into public.customers (
  id, company_name, contact_name, email, address, active, notes
) values
  ('31000000-0000-4000-8000-000000000001', 'Sentetik Market A',
   'Sentetik Müşteri A', 'customer.a@peksen.invalid',
   'Sentetik test adresi A; gerçek teslimat adresi değildir.', true, 'Yalnız yerel test.'),
  ('31000000-0000-4000-8000-000000000002', 'Sentetik Market B',
   'Sentetik Müşteri B', 'customer.b@peksen.invalid',
   'Sentetik test adresi B; gerçek teslimat adresi değildir.', true, 'Yalnız yerel test.');

insert into public.customer_users (customer_id, user_id, active) values
  ('31000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', true),
  ('31000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000008', true);

commit;
