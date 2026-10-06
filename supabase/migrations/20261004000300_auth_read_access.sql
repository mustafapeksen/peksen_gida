-- Phase 4: roles, scoped reads and audited identity/customer administration.
begin;
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter table public.customers
  add column created_by uuid references public.profiles(id),
  add column assigned_sales_operator_id uuid references public.profiles(id);
create index customers_sales_assignment_idx on public.customers(assigned_sales_operator_id);
create index customers_creator_idx on public.customers(created_by);

-- No role is taken from JWT user_metadata. Definer helpers avoid recursive
-- policies, live outside the exposed API schema and have fixed search paths.
create function private.current_app_role() returns public.app_role
language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p
  where p.id = (select auth.uid()) and p.active
    and (p.role <> 'customer' or exists (
      select 1 from public.customer_users cu join public.customers c on c.id = cu.customer_id
      where cu.user_id = p.id and cu.active and c.active
    ));
$$;
create function private.sales_customer(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.current_app_role() = 'sales_operator' and exists (
    select 1 from public.customers c where c.id = target
      and (c.created_by = (select auth.uid()) or c.assigned_sales_operator_id = (select auth.uid()))
  );
$$;
create function private.owns_customer(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.current_app_role() = 'customer' and exists (
    select 1 from public.customer_users cu join public.customers c on c.id = cu.customer_id
    where cu.user_id = (select auth.uid()) and cu.customer_id = target and cu.active and c.active
  );
$$;
create function private.assigned_run(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.current_app_role() = 'driver' and exists (
    select 1 from public.delivery_runs r where r.id = target
      and (r.primary_driver_id = (select auth.uid()) or r.assistant_driver_id = (select auth.uid()))
  );
$$;
create function private.can_read_order(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.orders o where o.id = target and (
    private.current_app_role() in ('manager','owner') or private.owns_customer(o.customer_id)
    or private.sales_customer(o.customer_id)
    or exists (select 1 from public.delivery_stops s join public.delivery_runs r on r.id = s.run_id
      where s.order_id = o.id and s.closed_at is null and r.ended_at is null
      and private.assigned_run(s.run_id))
  ));
$$;
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.current_app_role(), private.owns_customer(uuid),
  private.sales_customer(uuid), private.assigned_run(uuid), private.can_read_order(uuid) to authenticated;

-- Owner reads all source records. Manager reads operational records, excluding
-- salary, audit, settings and other users' inboxes. All writes remain revoked;
-- future transactional services must authorize, calculate and audit mutations.
do $$
declare t text;
begin
  foreach t in array array['profiles','customers','customer_users','categories','warehouses','vehicles',
    'products','product_units','product_price_history','pricing_rules','pricing_proposals','customer_pricing',
    'orders','order_items','order_status_history','order_approvals','order_change_requests','alternative_offers',
    'inventory','stock_counts','stock_count_items','inventory_movements','delivery_runs','delivery_stops',
    'driver_locations','delivery_confirmations','order_returns','order_return_items','payments',
    'payment_adjustments','ratings','employee_salary_records','notifications','app_settings','audit_logs'] loop
    execute format('grant select on public.%I to authenticated', t);
    execute format('create policy owner_read on public.%I for select to authenticated using ((select private.current_app_role()) = ''owner'')', t);
    if t not in ('employee_salary_records','audit_logs','app_settings','notifications') then
      execute format('create policy manager_read on public.%I for select to authenticated using ((select private.current_app_role()) = ''manager'')', t);
    end if;
  end loop;
end;
$$;

create policy own_profile on public.profiles for select to authenticated
  using (id = (select auth.uid()) and (select private.current_app_role()) is not null);
create policy own_membership on public.customer_users for select to authenticated
  using (user_id = (select auth.uid()) and active and private.owns_customer(customer_id));
create policy own_customer on public.customers for select to authenticated using (private.owns_customer(id));
create policy sales_customer on public.customers for select to authenticated using (private.sales_customer(id));
create policy own_pricing on public.customer_pricing for select to authenticated using (private.owns_customer(customer_id));
create policy sales_pricing on public.customer_pricing for select to authenticated using (private.sales_customer(customer_id));
create policy scoped_order on public.orders for select to authenticated using (private.can_read_order(id));
create policy scoped_order_item on public.order_items for select to authenticated using (private.can_read_order(order_id));
create policy scoped_order_history on public.order_status_history for select to authenticated using (private.can_read_order(order_id));
create policy own_payment on public.payments for select to authenticated
  using (exists (select 1 from public.orders o where o.id = payments.order_id and
    (private.owns_customer(o.customer_id) or private.sales_customer(o.customer_id))));
create policy own_rating on public.ratings for select to authenticated using (private.owns_customer(customer_id));
create policy own_notification on public.notifications for select to authenticated
  using (user_id = (select auth.uid()) and (select private.current_app_role()) is not null);
create policy assigned_run on public.delivery_runs for select to authenticated using (private.assigned_run(id));
create policy assigned_stop on public.delivery_stops for select to authenticated using (private.assigned_run(run_id));
create policy assigned_location on public.driver_locations for select to authenticated using (private.assigned_run(run_id));
create policy assigned_vehicle on public.vehicles for select to authenticated
  using (exists (select 1 from public.delivery_runs r where r.vehicle_id = vehicles.id and private.assigned_run(r.id)));

-- Accounting gets an explicit minimal projection, not raw customer rows (notes,
-- address and operational editing stay closed). Unassigned customers stay closed
-- pending clarification of that finance exception. No money is calculated here.
create function public.accounting_customers()
returns table(id uuid, company_name text, credit_limit_kurus bigint, payment_due_days integer)
language sql stable security definer set search_path = '' as $$
  select c.id, c.company_name, c.credit_limit_kurus, c.payment_due_days
  from public.customers c where private.current_app_role() = 'accounting'
    and (c.assigned_sales_operator_id is not null or exists (
      select 1 from public.profiles p where p.id = c.created_by and p.role = 'sales_operator'));
$$;

-- Role assignment only to an already provisioned Auth identity. Creating Auth
-- credentials/invitations requires the server-only Admin API, never a mobile key.
-- Both the OLD and NEW role are checked: Manager cannot demote a privileged user
-- first and then take over the account. Membership role conversions stay closed.
create function public.assign_account_role(target_user uuid, target_role public.app_role, display_name text)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); actor_role public.app_role; old_role public.app_role;
begin
  -- Serializes concurrent demotion and delegation using a deterministic lock order.
  perform 1 from auth.users where id in (actor,target_user) order by id for update;
  perform 1 from public.profiles where id in (actor, target_user) order by id for update;
  actor_role := private.current_app_role();
  select role into old_role from public.profiles where id = target_user;
  if actor_role is null or actor_role not in ('owner','manager') then
    raise exception using errcode = '42501', message = 'Account administration denied';
  end if;
  if actor_role = 'manager' and (target_role in ('owner','manager','accounting')
      or old_role in ('owner','manager','accounting')) then
    raise exception using errcode = '42501', message = 'Role delegation denied';
  end if;
  if (old_role = 'customer' and target_role <> 'customer') or
     (old_role is not null and old_role <> 'customer' and target_role = 'customer') then
    raise exception using errcode = '42501', message = 'Membership conversion requires a separate approved workflow';
  end if;
  if nullif(btrim(display_name),'') is null then
    raise exception using errcode = '22023', message = 'Display name required';
  end if;
  -- Lock the Auth parent as well to serialize first provisioning of a target.
  perform 1 from auth.users where id = target_user for update;
  if not found then raise exception using errcode = '23503', message = 'Auth identity required'; end if;
  insert into public.profiles(id,role,name,email) select id,target_role,btrim(display_name),email
    from auth.users where id = target_user
    on conflict (id) do update set role = excluded.role, name = excluded.name;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data)
    values (actor,'role_changed','profile',target_user,
      jsonb_build_object('role',old_role),jsonb_build_object('role',target_role));
end;
$$;

-- Customers cannot change provenance, assignments, active/credit/price fields.
-- Sales creates a customer under its own immutable provenance; Owner/Manager may
-- create an unassigned customer. Authentication credentials are a separate flow.
create function public.create_customer_record(company text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid; actor uuid := auth.uid();
begin
  perform 1 from public.profiles where id = actor for update;
  if private.current_app_role() is null or private.current_app_role() not in ('owner','manager','sales_operator') then
    raise exception using errcode = '42501', message = 'Customer creation denied';
  end if;
  if nullif(btrim(company),'') is null then raise exception using errcode='22023',message='Company required'; end if;
  insert into public.customers(company_name,created_by) values(btrim(company),actor) returning id into result;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data)
    values(actor,'permission_changed','customer',result,jsonb_build_object('created_by',actor));
  return result;
end;
$$;
create function public.assign_customer_sales(target_customer uuid, sales_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); old_sales uuid;
begin
  perform 1 from public.profiles where id in (actor,sales_user) order by id for update;
  if private.current_app_role() is null or private.current_app_role() not in ('owner','manager') then
    raise exception using errcode='42501',message='Customer assignment denied';
  end if;
  if sales_user is not null and not exists(select 1 from public.profiles
      where id=sales_user and role='sales_operator' and active) then
    raise exception using errcode='22023',message='Active Sales Operator required';
  end if;
  select assigned_sales_operator_id into old_sales from public.customers where id=target_customer for update;
  if not found then raise exception using errcode='22023',message='Customer not found'; end if;
  update public.customers set assigned_sales_operator_id=sales_user where id=target_customer;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data)
    values(actor,'permission_changed','customer',target_customer,
      jsonb_build_object('assigned_sales_operator_id',old_sales),jsonb_build_object('assigned_sales_operator_id',sales_user));
end;
$$;
create function public.update_customer_contact(target_customer uuid, company text,
  contact text, contact_phone text, contact_email text, delivery_address text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.profiles where id=auth.uid() for update;
  perform 1 from public.customers where id=target_customer for update;
  if not found or not coalesce(private.current_app_role() in ('owner','manager')
      or private.sales_customer(target_customer),false) then
    raise exception using errcode='42501',message='Customer management denied';
  end if;
  if nullif(btrim(company),'') is null then raise exception using errcode='22023',message='Company required'; end if;
  update public.customers set company_name=btrim(company),contact_name=contact,phone=contact_phone,
    email=contact_email,address=delivery_address where id=target_customer;
end;
$$;
-- Provision the organization relationship atomically with a customer profile.
-- Auth credential creation is still server-only. No caller chooses another
-- organization through self-service metadata; no implicit membership transfer.
create function public.link_customer_account(target_user uuid, target_customer uuid, display_name text)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  perform public.assign_account_role(target_user,'customer',display_name);
  perform 1 from public.customers where id=target_customer for update;
  if not found then raise exception using errcode='23503',message='Customer required'; end if;
  if exists(select 1 from public.customer_users where user_id=target_user
      and (customer_id<>target_customer or not active)) then
    raise exception using errcode='42501',message='Membership transfer/reactivation requires an approved workflow';
  end if;
  insert into public.customer_users(customer_id,user_id) values(target_customer,target_user)
    on conflict (customer_id,user_id) do nothing;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data)
    values(actor,'permission_changed','customer',target_customer,jsonb_build_object('user_id',target_user));
end;
$$;
revoke all on function public.accounting_customers(), public.assign_account_role(uuid,public.app_role,text),
  public.create_customer_record(text),public.assign_customer_sales(uuid,uuid),
  public.update_customer_contact(uuid,text,text,text,text,text), public.link_customer_account(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.accounting_customers(), public.assign_account_role(uuid,public.app_role,text),
  public.create_customer_record(text),public.assign_customer_sales(uuid,uuid),
  public.update_customer_contact(uuid,text,text,text,text,text), public.link_customer_account(uuid,uuid,text) to authenticated;

-- Signup/invites, financial mutations, Warehouse workflow and customer GPS remain
-- separate decisions/phases. Only the bounded identity/customer RPCs can write.
comment on schema private is 'Phase 4 RLS helpers; not exposed by the Supabase Data API';
commit;
