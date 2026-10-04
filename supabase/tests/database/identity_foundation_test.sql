begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(19);
select has_table('public', 'profiles', 'Profiles migration exists');
select has_table('public', 'customers', 'Customers migration exists');
select has_table('public', 'customer_users', 'Membership migration exists');
select results_eq(
  $$ select unnest(enum_range(null::public.app_role))::text $$,
  $$ values ('customer'), ('sales_operator'), ('warehouse'), ('accounting'),
            ('driver'), ('manager'), ('owner') $$,
  'Exactly the seven source roles exist'
);
select is((select count(*) from public.profiles), 8::bigint, 'Eight synthetic profiles');
select is((select count(distinct role) from public.profiles), 7::bigint, 'All roles seeded');
select is((select count(*) from public.customers), 2::bigint, 'Two independent customers');
select is((select count(*) from public.customer_users), 2::bigint, 'Two memberships');
select is((select count(*) from auth.users u join public.profiles p on p.id = u.id
           join auth.identities i on i.user_id = u.id where i.provider = 'email'),
          8::bigint, 'All profiles have email auth identities');
select ok(not exists(select 1 from public.profiles where email not like '%@peksen.invalid'),
          'No real email addresses');
select is((select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relname in ('profiles','customers','customer_users')
           and c.relrowsecurity), 3::bigint, 'All foundation tables enable RLS');
select is((select count(*) from pg_policies where schemaname = 'public'
           and tablename in ('profiles','customers','customer_users')),
          0::bigint, 'No application access policy is invented');
select throws_ok(
  $$ insert into public.customer_users values
     ('31000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000008', true) $$,
  '23505', null::text, 'Second user for one organization is rejected'
);
select throws_ok(
  $$ insert into public.profiles (id,role,name) values
     ('30000000-0000-4000-8000-000000000099','customer','Missing auth user') $$,
  '23503', null::text, 'Profile requires an auth user'
);
set local role anon;
select throws_ok($$ select * from public.customers $$, '42501', null::text,
                 'Anonymous customer reads are closed');
reset role;
set local role authenticated;
select throws_ok($$ select * from public.profiles $$, '42501', null::text,
                 'Authenticated profile reads are closed until Phase 4');
select throws_ok($$ update public.profiles set role = 'owner' $$, '42501', null::text,
                 'Client cannot assign roles');
select throws_ok($$ select * from public.customer_users $$, '42501', null::text,
                 'Client membership reads are closed');
select throws_ok($$ insert into public.customers (company_name) values ('Denied') $$,
                 '42501', null::text, 'Client customer writes are closed');
reset role;
select * from finish();
rollback;
