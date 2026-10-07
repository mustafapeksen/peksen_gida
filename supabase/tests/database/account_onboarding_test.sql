begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

-- Customer-controlled metadata cannot pick a role or an existing organization.
insert into auth.users(id,email,raw_user_meta_data) values
 ('71000000-0000-4000-8000-000000000001','signup@peksen.invalid',
 '{"signup_type":"customer","name":"New customer","company":"New company","role":"owner","customer_id":"31000000-0000-4000-8000-000000000001"}');
select is((select role::text from profiles where id='71000000-0000-4000-8000-000000000001'),'customer','Signup ignores injected role');
select ok((select active from profiles where id='71000000-0000-4000-8000-000000000001'),'Customer active without manager approval');
select is((select count(*) from customer_users where user_id='71000000-0000-4000-8000-000000000001'),1::bigint,'Signup creates one membership');
select isnt((select customer_id::text from customer_users where user_id='71000000-0000-4000-8000-000000000001'),
 '31000000-0000-4000-8000-000000000001','Signup never joins client-chosen organization');
select throws_ok($$insert into auth.users(id,email,raw_user_meta_data) values(gen_random_uuid(),'bad@peksen.invalid',
 '{"signup_type":"customer","name":"X","company":""}')$$,'22023',null::text,'Invalid signup atomically rejected');
select is((select count(*) from auth.users where email='bad@peksen.invalid'),0::bigint,'Invalid signup leaves no Auth identity');

set local role anon;
select throws_ok($$select create_account_invitation('invite@peksen.invalid','Name','owner')$$,'42501',null::text,'Anon cannot invite');
select throws_ok($$select accept_account_invitation()$$,'42501',null::text,'Anon cannot accept');
select throws_ok($$select account_invitation_accepted()$$,'42501',null::text,'Anon cannot read acceptance state');
select throws_ok($$select set_account_active('30000000-0000-4000-8000-000000000007',false)$$,'42501',null::text,'Anon cannot deactivate');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select throws_ok($$select create_account_invitation('invite@peksen.invalid','Name','driver')$$,'42501',null::text,'Customer cannot invite');
select throws_ok($$select set_account_active(auth.uid(),false)$$,'42501',null::text,'Self account closure not granted');
select is((select count(*) from account_invitations()),0::bigint,'Customer invitation list closed');
select throws_ok($$select * from private.account_invitations$$,'42501',null::text,'Raw invitation rows closed');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select throws_ok($$select create_account_invitation('owner.invite@peksen.invalid','Name','owner')$$,'42501',null::text,'Manager cannot invite Owner');
select throws_ok($$select create_account_invitation('manager.invite@peksen.invalid','Name','manager')$$,'42501',null::text,'Manager cannot invite Manager');
select throws_ok($$select create_account_invitation('accounting.invite@peksen.invalid','Name','accounting')$$,'42501',null::text,'Manager cannot invite Accounting');
select throws_ok($$select create_account_invitation('owner@peksen.invalid','Name','driver')$$,'22023',null::text,'Invite cannot take over an existing account');
select throws_ok($$select create_account_invitation('customer.invite@peksen.invalid','Name','customer')$$,'22023',null::text,'Customer invite requires explicit organization');
select throws_ok($$select create_account_invitation('customer.invite@peksen.invalid','Name','customer','31000000-0000-4000-8000-000000000001')$$,
 '22023',null::text,'Customer invite cannot occupy existing membership');
select lives_ok($$select create_account_invitation('worker@peksen.invalid','Worker','driver')$$,'Manager invites operational role');
select lives_ok($$select create_account_invitation('revoke@peksen.invalid','Worker','warehouse')$$,'Manager invites Warehouse');
select throws_ok($$select create_account_invitation('worker@peksen.invalid','Worker','warehouse')$$,'23505',null::text,'Duplicate pending invitation rejected');
select is((select count(*) from account_invitations()),2::bigint,'Manager sees own invitations');
select lives_ok($$select revoke_account_invitation(id) from account_invitations() where email='revoke@peksen.invalid'$$,'Manager may revoke own unaccepted invitation');
select throws_ok($$select set_account_active('30000000-0000-4000-8000-000000000003',false)$$,'42501',null::text,'Manager activation denied');
reset role;
insert into auth.users(id,email,raw_user_meta_data) values
 ('71000000-0000-4000-8000-000000000002','worker@peksen.invalid','{"role":"owner"}'),
 ('71000000-0000-4000-8000-000000000003','outsider@peksen.invalid','{}');
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select throws_ok($$select accept_account_invitation()$$,'42501',null::text,'Unverified email cannot consume invitation');
select is(account_invitation_accepted(),false,'Unverified identity cannot claim accepted state');
reset role;
update auth.users set email_confirmed_at=now() where id in ('71000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000003');
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select throws_ok($$select accept_account_invitation()$$,'42501',null::text,'Verified different email cannot steal invitation');
reset role;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select lives_ok($$select accept_account_invitation()$$,'Verified invited identity completes provisioning');
select is(private.current_app_role()::text,'driver','Accepted role comes from server invitation, not metadata');
select lives_ok($$select accept_account_invitation()$$,'Acceptance retry is idempotent');
select is(account_invitation_accepted(),true,'Verified recipient reads its own accepted state');
select is((select count(*) from employee_salary_records),0::bigint,'Invitation cannot grant Owner salary access');
reset role;
select is((select count(*) from audit_logs where entity_id='71000000-0000-4000-8000-000000000002' and action='role_changed'),1::bigint,'Acceptance audited exactly once');
update profiles set active=false where id='71000000-0000-4000-8000-000000000002';
set local role authenticated;
select is(account_invitation_accepted(),true,'Inactive recipient retains completion state without gaining profile access');
select is((select count(*) from profiles),0::bigint,'Completion status does not bypass inactive profile RLS');
reset role;
update profiles set active=true where id='71000000-0000-4000-8000-000000000002';

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select lives_ok($$select create_account_invitation('stale@peksen.invalid','Stale','sales_operator')$$,'Create invite for live-authority regression');
reset role;
insert into auth.users(id,email,email_confirmed_at) values('71000000-0000-4000-8000-000000000004','stale@peksen.invalid',now());
update profiles set active=false where id='30000000-0000-4000-8000-000000000006';
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000004',true);
set local role authenticated;
select throws_ok($$select accept_account_invitation()$$,'42501',null::text,'Inactive inviter cannot delegate via old invitation');
reset role;
select ok(not exists(select 1 from profiles where id='71000000-0000-4000-8000-000000000004'),'Rejected acceptance leaves no profile');
update profiles set active=true where id='30000000-0000-4000-8000-000000000006';
update private.account_invitations set expires_at=now()-interval '1 second' where email='stale@peksen.invalid';
set local role authenticated;
select throws_ok($$select accept_account_invitation()$$,'42501',null::text,'Expired invitation denied');
reset role;

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select lives_ok($$select create_account_invitation('finance@peksen.invalid','Finance','accounting')$$,'Owner can invite Accounting');
select lives_ok($$select set_account_active('30000000-0000-4000-8000-000000000001',false)$$,'Owner deactivates customer without deletion');
select is((select active from profiles where id='30000000-0000-4000-8000-000000000001'),false,'Disabled profile retained');
select is((select count(*) from orders where customer_id='31000000-0000-4000-8000-000000000001'),2::bigint,'Customer order history retained');
select throws_ok($$select set_account_active(auth.uid(),false)$$,'55000',null::text,'Last active Owner cannot be disabled');
select throws_ok($$select assign_account_role(auth.uid(),'driver','Demote')$$,'55000',null::text,'Role delegation cannot remove last Owner');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select count(*) from profiles),0::bigint,'Disabled customer immediately loses profile access');
select is((select count(*) from orders),0::bigint,'Disabled customer immediately loses business access');
reset role;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select lives_ok($$select set_account_active('30000000-0000-4000-8000-000000000001',true)$$,'Owner can reopen customer');
reset role;
update customers set assigned_sales_operator_id='30000000-0000-4000-8000-000000000002'
 where id='31000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select set_account_active('30000000-0000-4000-8000-000000000002',false)$$,'55000',null::text,'Assigned Sales cannot be disabled');
reset role;
insert into delivery_runs(vehicle_id,primary_driver_id,status) select id,'30000000-0000-4000-8000-000000000005','assigned' from vehicles limit 1;
set local role authenticated;
select throws_ok($$select set_account_active('30000000-0000-4000-8000-000000000005',false)$$,'55000',null::text,'Driver with open run cannot be disabled');
select lives_ok($$select set_account_active('30000000-0000-4000-8000-000000000003',false)$$,'Unassigned employee can be disabled');
select lives_ok($$select set_account_active('30000000-0000-4000-8000-000000000003',true)$$,'Owner reopens employee');
reset role;
select * from finish();
rollback;
