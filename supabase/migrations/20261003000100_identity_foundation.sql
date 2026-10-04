-- Phase 3 independent foundation, SPEC sections 2, 3, 25.
-- Business tables await DECISIONS A-01..A-13; no workflow/formula is inferred.
begin;

create type public.app_role as enum (
  'customer', 'sales_operator', 'warehouse', 'accounting',
  'driver', 'manager', 'owner'
);

create table public.profiles (
  id uuid primary key references auth.users(id),
  role public.app_role not null,
  name text not null,
  email text,
  phone text,
  active boolean not null default true
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  company_name text not null,
  customer_type text,
  contact_name text,
  phone text,
  email text,
  address text,
  tax_no text,
  tax_office text,
  active boolean not null default true,
  notes text
);

create table public.customer_users (
  customer_id uuid not null references public.customers(id),
  user_id uuid not null references public.profiles(id),
  active boolean not null default true,
  primary key (customer_id, user_id),
  -- SPEC section 3: one user per organization in the MVP.
  constraint customer_users_one_user_per_customer unique (customer_id)
);

create index customer_users_user_id_idx on public.customer_users(user_id);

-- Closed by default until Phase 4's reviewed access policies are implemented.
-- No client grants, no policies, no automatic role from user-controlled metadata.
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.customer_users enable row level security;
revoke all on table public.profiles, public.customers, public.customer_users
  from public, anon, authenticated;

comment on table public.profiles is
  'Phase 3 foundation only; roles are database data, not client metadata.';
comment on table public.customer_users is
  'MVP one user per customer; membership authorization is deferred to Phase 4.';

commit;
