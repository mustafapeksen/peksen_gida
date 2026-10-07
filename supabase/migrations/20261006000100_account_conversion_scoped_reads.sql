-- Phase 4: the three explicitly approved continuation decisions (F4-04).
-- No credential provisioning, financial mutation or warehouse workflow.
begin;

-- A creator relationship is NOT a Sales assignment for Accounting.
drop function public.accounting_customers();
create function public.accounting_customers()
returns table(id uuid, company_name text, contact_name text, phone text, email text,
  address text, tax_no text, tax_office text, credit_limit_kurus bigint, payment_due_days integer)
language sql stable security definer set search_path = '' as $$
  select c.id,c.company_name,c.contact_name,c.phone,c.email,c.address,c.tax_no,c.tax_office,
    c.credit_limit_kurus,c.payment_due_days
  from public.customers c where private.current_app_role() = 'accounting'
    and c.assigned_sales_operator_id is not null;
$$;
create function public.accounting_payments()
returns table(id uuid, customer_id uuid, order_id uuid, payment_amount_kurus bigint,
  method text, collector_user_id uuid, collected_at timestamptz,
  verified_by uuid, verified_at timestamptz, verification_status text)
language sql stable security definer set search_path = '' as $$
  select p.id,o.customer_id,p.order_id,p.payment_amount_kurus,p.method,p.collector_user_id,
    p.collected_at,p.verified_by,p.verified_at,p.verification_status
  from public.payments p join public.orders o on o.id=p.order_id
    join public.customers c on c.id=o.customer_id
  where private.current_app_role() = 'accounting' and c.assigned_sales_operator_id is not null;
$$;
create function public.accounting_payment_adjustments()
returns table(id uuid, payment_id uuid, adjustment_amount_kurus bigint, created_by uuid, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select a.id,a.payment_id,a.adjustment_amount_kurus,a.created_by,a.created_at
  from public.payment_adjustments a join public.payments p on p.id=a.payment_id
    join public.orders o on o.id=p.order_id join public.customers c on c.id=o.customer_id
  where private.current_app_role() = 'accounting' and c.assigned_sales_operator_id is not null;
$$;

-- RLS filters rows, not columns. Never grant Warehouse a raw product/order row:
-- prices, discounts and customer data must not leak through SELECT * or joins.
create function public.warehouse_products()
returns table(id uuid, sku text, name text, package_label text, base_unit text, active boolean)
language sql stable security definer set search_path = '' as $$
  select p.id,p.sku,p.name,p.package_label,p.base_unit,p.active from public.products p
  where private.current_app_role() = 'warehouse';
$$;
create function public.warehouse_preparation_items()
returns table(order_id uuid, item_id uuid, status text, product_id uuid, product_unit_id uuid,
  unit text, conversion_to_base_snapshot numeric, quantity integer, picked_qty integer)
language sql stable security definer set search_path = '' as $$
  select o.id,i.id,o.status::text,i.product_id,i.product_unit_id,i.unit,
    i.conversion_to_base_snapshot::numeric,i.quantity,i.picked_qty
  from public.orders o join public.order_items i on i.order_id=o.id
  where private.current_app_role() = 'warehouse' and o.status in ('submitted','picking','picked');
$$;
create function public.warehouse_stock_counts()
returns table(id uuid, warehouse_id uuid, status text, created_by uuid, created_at timestamptz,
  approved_by uuid, approved_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select c.id,c.warehouse_id,c.status,c.created_by,c.created_at,c.approved_by,c.approved_at
  from public.stock_counts c where private.current_app_role() = 'warehouse';
$$;
create function public.warehouse_movements()
returns table(id uuid, warehouse_id uuid, product_id uuid, type text, quantity numeric,
  physical_delta numeric, reserved_delta numeric, order_item_id uuid, stock_count_id uuid,
  compensates_movement_id uuid, unit text, conversion_to_base_snapshot numeric, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select m.id,m.warehouse_id,m.product_id,m.type,m.quantity::numeric,m.physical_delta,m.reserved_delta,
    m.order_item_id,m.stock_count_id,m.compensates_movement_id,m.unit,
    m.conversion_to_base_snapshot::numeric,m.created_at
  from public.inventory_movements m where private.current_app_role() = 'warehouse';
$$;
create policy warehouse_units_read on public.product_units for select to authenticated
  using ((select private.current_app_role()) = 'warehouse');
create policy warehouse_inventory_read on public.inventory for select to authenticated
  using ((select private.current_app_role()) = 'warehouse');
create policy warehouse_count_items_read on public.stock_count_items for select to authenticated
  using ((select private.current_app_role()) = 'warehouse');

-- Separate from ordinary role delegation so the old Manager restrictions hold.
-- A destination organization is mandatory only for employee -> customer.
create function public.convert_account_role(target_user uuid, target_role public.app_role,
  target_customer uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); old_role public.app_role; old_memberships jsonb;
begin
  -- Same lock order as assign_account_role and link_customer_account.
  perform 1 from auth.users where id in (actor,target_user) order by id for update;
  perform 1 from public.profiles where id in (actor,target_user) order by id for update;
  if private.current_app_role() is distinct from 'owner' then
    raise exception using errcode='42501',message='Only Owner may convert an account';
  end if;
  select p.role into old_role from public.profiles p where p.id=target_user;
  if old_role is null or target_role is null or
      ((old_role = 'customer') = (target_role = 'customer')) then
    raise exception using errcode='22023',message='Existing customer/employee conversion required';
  end if;
  -- Preserve every historical membership; never move or delete it.
  perform 1 from public.customers where id=target_customer or id in (
    select cu.customer_id from public.customer_users cu where cu.user_id=target_user
  ) order by id for update;
  perform 1 from public.customer_users where user_id=target_user order by customer_id for update;
  select coalesce(jsonb_agg(jsonb_build_object('customer_id',cu.customer_id,'active',cu.active)
    order by cu.customer_id),'[]'::jsonb) into old_memberships
    from public.customer_users cu where cu.user_id=target_user;

  if target_role = 'customer' then
    if target_customer is null or not exists(select 1 from public.customers
        where id=target_customer and active) then
      raise exception using errcode='22023',message='Explicit active empty customer organization required';
    end if;
    if exists(select 1 from public.customer_users where customer_id=target_customer) then
      raise exception using errcode='22023',message='Destination organization already has membership history';
    end if;
    -- Existing live assignment fields only. created_by is historical provenance,
    -- not a work assignment; no invented order/task status or task table.
    if exists(select 1 from public.customers where assigned_sales_operator_id=target_user)
      or exists(select 1 from public.delivery_runs r
        where (r.primary_driver_id=target_user or r.assistant_driver_id=target_user)
          and (r.ended_at is null or exists(select 1 from public.delivery_stops s
            where s.run_id=r.id and s.closed_at is null))) then
      raise exception using errcode='55000',message='Open work assignments must be closed or reassigned first';
    end if;
    update public.customer_users set active=false where user_id=target_user and active;
    insert into public.customer_users(customer_id,user_id,active) values(target_customer,target_user,true);
  else
    if target_customer is not null then
      raise exception using errcode='22023',message='Employee conversion cannot attach a customer organization';
    end if;
    update public.customer_users set active=false where user_id=target_user and active;
  end if;
  -- Do not reactivate a disabled profile or change its contact/Auth identity.
  update public.profiles set role=target_role where id=target_user;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data)
    values(actor,'role_changed','profile',target_user,
      jsonb_build_object('role',old_role,'memberships',old_memberships),
      jsonb_build_object('role',target_role,'customer_id',target_customer));
end;
$$;

revoke all on function public.accounting_customers(),public.accounting_payments(),
  public.accounting_payment_adjustments(),public.warehouse_products(),public.warehouse_preparation_items(),
  public.warehouse_stock_counts(),public.warehouse_movements(),
  public.convert_account_role(uuid,public.app_role,uuid) from public,anon,authenticated;
grant execute on function public.accounting_customers(),public.accounting_payments(),
  public.accounting_payment_adjustments(),public.warehouse_products(),public.warehouse_preparation_items(),
  public.warehouse_stock_counts(),public.warehouse_movements(),
  public.convert_account_role(uuid,public.app_role,uuid) to authenticated;
commit;
