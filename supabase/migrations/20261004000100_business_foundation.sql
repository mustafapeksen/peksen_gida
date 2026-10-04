-- Phase 3 schema only. Approved decisions B-01..B-09 and technical T-12.
-- No workflow RPC, client grants, authorization policy or pricing formula.
begin;

-- Unbounded NUMERIC is exact; reject NaN/infinities without inventing a scale.
create domain public.stock_quantity as numeric
  check (value >= 0 and value < 'Infinity'::numeric);
create domain public.discount_fraction as numeric
  check (value >= 0 and value <= 1);
create domain public.order_state as text check (value in ('draft','pending_approval','submitted','picking',
  'picked','assigned','loaded','out_for_delivery','delivery_pending_confirmation',
  'delivered','delivery_disputed','cancelled','rejected'));

alter table public.customers
  add column credit_limit_kurus bigint check (credit_limit_kurus >= 0),
  add column payment_due_days integer check (payment_due_days >= 0);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true
);
create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  singleton boolean not null default true check (singleton),
  unique (singleton)
);
create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  plate text not null unique check (btrim(plate) <> ''),
  active boolean not null default true,
  description text
);
create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  name text not null,
  category_id uuid not null references public.categories(id),
  description text,
  package_label text,
  base_unit text not null,
  min_quantity integer not null check (min_quantity > 0),
  unit_price_kurus bigint not null check (unit_price_kurus >= 0),
  active boolean not null default true
);
create table public.product_units (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  unit_name text not null,
  conversion_to_base public.stock_quantity not null check (conversion_to_base > 0),
  orderable boolean not null default true,
  unique (product_id, unit_name), unique (id, product_id)
);
create table public.product_price_history (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  old_price_kurus bigint not null check (old_price_kurus >= 0),
  new_price_kurus bigint not null check (new_price_kurus >= 0),
  changed_by uuid not null references public.profiles(id),
  reason text not null check (btrim(reason) <> ''),
  created_at timestamptz not null default now(),
  operation_key uuid not null unique
);
create table public.pricing_rules (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  threshold_kurus bigint not null check (threshold_kurus >= 0),
  discount_rate public.discount_fraction not null,
  active boolean not null default true
);
create table public.pricing_proposals (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  quarter_start date not null check (extract(day from quarter_start) = 1
    and extract(month from quarter_start) in (1,4,7,10)),
  net_order_total_kurus bigint not null check (net_order_total_kurus >= 0),
  pricing_rule_id uuid references public.pricing_rules(id),
  proposed_discount_rate public.discount_fraction not null,
  status text not null check (status in ('pending','approved','rejected')),
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  reason text,
  operation_key uuid unique,
  unique (id, customer_id),
  check ((status = 'pending' and decided_by is null and decided_at is null and operation_key is null)
    or (status <> 'pending' and decided_by is not null and decided_at is not null and operation_key is not null))
);
create table public.customer_pricing (
  customer_id uuid primary key references public.customers(id),
  discount_rate public.discount_fraction not null,
  source text not null,
  effective_from date not null,
  proposal_id uuid,
  foreign key (proposal_id, customer_id) references public.pricing_proposals(id, customer_id)
);
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  created_by uuid not null references public.profiles(id),
  source text not null check (source in ('customer_app','sales_operator')),
  status public.order_state not null,
  payment_status text not null check (payment_status in ('not_due','unpaid','partial','paid','overdue','disputed')),
  subtotal_kurus bigint not null check (subtotal_kurus >= 0),
  discount_total_kurus bigint not null check (discount_total_kurus >= 0),
  total_kurus bigint not null check (total_kurus >= 0),
  credit_warning boolean not null default false,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  payment_due_days_snapshot integer check (payment_due_days_snapshot >= 0),
  due_date timestamptz,
  operation_key uuid not null unique,
  unique (id, customer_id),
  check (discount_total_kurus <= subtotal_kurus),
  check (total_kurus = subtotal_kurus - discount_total_kurus),
  check (due_date is null or (delivered_at is not null and payment_due_days_snapshot is not null))
);
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  product_id uuid not null references public.products(id),
  product_unit_id uuid not null,
  unit text not null,
  conversion_to_base_snapshot public.stock_quantity not null check (conversion_to_base_snapshot > 0),
  quantity integer not null check (quantity > 0),
  picked_qty integer not null default 0 check (picked_qty >= 0 and picked_qty <= quantity),
  unit_price_kurus bigint not null check (unit_price_kurus >= 0),
  discount_rate_snapshot public.discount_fraction not null,
  final_unit_price_kurus bigint not null check (final_unit_price_kurus >= 0),
  line_total_kurus bigint not null check (line_total_kurus >= 0),
  foreign key (product_unit_id, product_id) references public.product_units(id, product_id),
  unique (id, order_id), unique (id, product_id)
);
create table public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  from_status public.order_state,
  to_status public.order_state not null,
  changed_by uuid not null references public.profiles(id),
  reason text,
  created_at timestamptz not null default now(),
  operation_key uuid not null unique,
  check (from_status is distinct from to_status)
);
create table public.order_approvals (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  reason text not null check (btrim(reason) <> ''),
  requested_by uuid not null references public.profiles(id),
  status text not null check (status in ('pending','approved','rejected')),
  projected_exposure_kurus bigint check (projected_exposure_kurus >= 0),
  credit_limit_kurus bigint check (credit_limit_kurus >= 0),
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  decision_reason text,
  operation_key uuid unique,
  check ((status = 'pending' and decided_by is null and decided_at is null and operation_key is null)
    or (status <> 'pending' and decided_by is not null and decided_at is not null and operation_key is not null))
);
create table public.order_change_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  type text not null check (type in ('cancel','change')),
  requested_by uuid not null references public.profiles(id),
  reason text not null,
  status text not null check (status in ('pending','approved','rejected')),
  proposed_changes jsonb,
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.alternative_offers (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references public.order_items(id),
  offered_product_id uuid not null references public.products(id),
  offered_unit_id uuid not null,
  offered_qty integer not null check (offered_qty > 0),
  status text not null check (status in ('pending','accepted','rejected')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  responded_by uuid references public.profiles(id),
  responded_at timestamptz,
  operation_key uuid unique,
  foreign key (offered_unit_id, offered_product_id) references public.product_units(id, product_id),
  check ((status = 'pending' and responded_by is null and responded_at is null and operation_key is null)
    or (status <> 'pending' and responded_by is not null and responded_at is not null and operation_key is not null))
);
create table public.inventory (
  warehouse_id uuid not null references public.warehouses(id),
  product_id uuid not null references public.products(id),
  physical_qty public.stock_quantity not null,
  reserved_qty public.stock_quantity not null,
  available_qty numeric generated always as (physical_qty - reserved_qty) stored,
  primary key (warehouse_id, product_id),
  check (reserved_qty <= physical_qty)
);
create table public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references public.warehouses(id),
  created_by uuid not null references public.profiles(id),
  approved_by uuid references public.profiles(id),
  status text not null check (status in ('draft','pending','approved','rejected')),
  reason text,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  operation_key uuid unique,
  check (status <> 'approved' or (approved_by is not null and approved_at is not null and operation_key is not null))
);
create table public.stock_count_items (
  stock_count_id uuid not null references public.stock_counts(id),
  product_id uuid not null references public.products(id),
  system_qty public.stock_quantity not null,
  counted_qty public.stock_quantity not null,
  difference numeric generated always as (counted_qty - system_qty) stored,
  reason text,
  primary key (stock_count_id, product_id)
);
create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references public.warehouses(id),
  product_id uuid not null references public.products(id),
  type text not null check (type in ('received','reserved','picked','released','returned','count_adjustment','compensation')),
  quantity public.stock_quantity not null check (quantity > 0),
  physical_delta numeric not null check (abs(physical_delta) < 'Infinity'::numeric),
  reserved_delta numeric not null check (abs(reserved_delta) < 'Infinity'::numeric),
  order_item_id uuid,
  stock_count_id uuid references public.stock_counts(id),
  compensates_movement_id uuid references public.inventory_movements(id),
  reference_type text,
  reference_id uuid,
  unit text,
  conversion_to_base_snapshot public.stock_quantity check (conversion_to_base_snapshot > 0),
  document_note text,
  reason text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  operation_key uuid not null unique,
  foreign key (order_item_id, product_id) references public.order_items(id, product_id),
  check (physical_delta <> 0 or reserved_delta <> 0),
  check (type <> 'reserved' or (physical_delta = 0 and reserved_delta = quantity)),
  check (type <> 'picked' or (physical_delta = -quantity and reserved_delta = -quantity)),
  check (type <> 'released' or (physical_delta = 0 and reserved_delta = -quantity)),
  check (type <> 'count_adjustment' or stock_count_id is not null)
);
create table public.delivery_runs (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id),
  primary_driver_id uuid not null references public.profiles(id),
  assistant_driver_id uuid references public.profiles(id),
  status text not null,
  started_at timestamptz,
  ended_at timestamptz,
  check (primary_driver_id is distinct from assistant_driver_id),
  check (ended_at is null or (started_at is not null and ended_at >= started_at))
);
create table public.delivery_stops (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.delivery_runs(id),
  order_id uuid not null references public.orders(id),
  sequence integer not null check (sequence > 0),
  status text not null,
  arrived_at timestamptz,
  completed_at timestamptz,
  assigned_by uuid not null references public.profiles(id),
  assigned_at timestamptz not null default now(),
  closed_at timestamptz,
  closed_by uuid references public.profiles(id),
  close_reason text,
  previous_stop_id uuid references public.delivery_stops(id),
  check ((closed_at is null and closed_by is null) or (closed_at is not null and closed_by is not null)),
  check (closed_at is null or closed_at >= assigned_at)
);
create unique index delivery_stops_one_active_order on public.delivery_stops(order_id) where closed_at is null;
create unique index delivery_stops_active_sequence on public.delivery_stops(run_id, sequence) where closed_at is null;
create table public.driver_locations (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.delivery_runs(id),
  driver_id uuid not null references public.profiles(id),
  latitude numeric not null check (latitude between -90 and 90),
  longitude numeric not null check (longitude between -180 and 180),
  recorded_at timestamptz not null
);
create table public.delivery_confirmations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  event_type text not null check (event_type in ('driver','customer','dispute','resolution')),
  driver_confirmed boolean not null default false,
  customer_confirmed boolean not null default false,
  finalizes_delivery boolean not null default false,
  performed_by uuid not null references public.profiles(id),
  dispute_reason text,
  resolution_reason text,
  created_at timestamptz not null default now(),
  operation_key uuid not null unique,
  check (not driver_confirmed or event_type = 'driver'),
  check (not customer_confirmed or event_type = 'customer'),
  check (not finalizes_delivery or event_type in ('customer','resolution')),
  check (event_type <> 'resolution' or nullif(btrim(resolution_reason),'') is not null)
);
create unique index delivery_confirmations_one_party_confirmation on public.delivery_confirmations(order_id,event_type)
  where event_type in ('driver','customer');
create table public.order_returns (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  created_by uuid not null references public.profiles(id),
  reason text not null,
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, order_id),
  check ((approved_at is null) = (approved_by is null))
);
create table public.order_return_items (
  return_id uuid not null,
  order_id uuid not null,
  order_item_id uuid not null,
  quantity integer not null check (quantity > 0),
  return_amount_kurus bigint not null check (return_amount_kurus >= 0),
  primary key (return_id, order_item_id),
  foreign key (return_id, order_id) references public.order_returns(id, order_id),
  foreign key (order_item_id, order_id) references public.order_items(id, order_id)
);
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  payment_amount_kurus bigint not null check (payment_amount_kurus > 0),
  method text not null check (method in ('cash','pos')),
  collector_user_id uuid not null references public.profiles(id),
  collected_at timestamptz not null,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  verification_status text not null check (verification_status in ('recorded','verified','disputed','cancelled')),
  note text,
  operation_key uuid not null unique,
  check (verification_status <> 'verified' or (verified_by is not null and verified_at is not null))
);
create table public.payment_adjustments (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id),
  adjustment_amount_kurus bigint not null check (adjustment_amount_kurus <> 0),
  reason text not null check (btrim(reason) <> ''),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  operation_key uuid not null unique
);
create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique,
  customer_id uuid not null,
  driver_id uuid not null references public.profiles(id),
  score integer not null check (score between 1 and 5),
  reason_codes text[] not null default '{}',
  comment text,
  foreign key (order_id, customer_id) references public.orders(id, customer_id)
);
create table public.employee_salary_records (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id),
  period date not null,
  salary_kurus bigint not null check (salary_kurus >= 0),
  bonus_kurus bigint not null check (bonus_kurus >= 0),
  created_by uuid not null references public.profiles(id)
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  type text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id uuid,
  deep_link text,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create table public.app_settings (
  key text primary key check (key in ('default_payment_due_days')),
  value jsonb not null,
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now(),
  constraint app_settings_typed_value check (case when key = 'default_payment_due_days'
    and jsonb_typeof(value) = 'number' and value::text ~ '^[0-9]+$'
    then (value::text)::numeric between 0 and 2147483647
    else false end)
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id),
  action text not null check (action in ('price_changed','stock_movement','stock_count_approved',
    'order_status_changed','alternative_accepted','alternative_rejected','payment_recorded',
    'payment_corrected','payment_cancelled','credit_approved','credit_rejected',
    'delivery_disputed','delivery_resolved','role_changed','permission_changed')),
  entity_type text not null,
  entity_id uuid not null,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now(),
  operation_key uuid
);

-- Append-only facts; correction is a new record, never rewriting the evidence.
create function public.reject_fact_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception using errcode = '23514', message = 'Historical facts require a compensating record';
end;
$$;
revoke all on function public.reject_fact_mutation() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['product_price_history','order_status_history','inventory_movements',
    'delivery_confirmations','payment_adjustments','audit_logs'] loop
    execute format('create trigger immutable_fact before update or delete on public.%I for each row execute function public.reject_fact_mutation()', t);
  end loop;
end;
$$;
-- Verification metadata can change in a future audited transaction; payment
-- principal/order/collector and the original operation key cannot be rewritten.
create function public.protect_payment_fact() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '23514', message = 'Payments cannot be deleted';
  end if;
  if row(new.id,new.order_id,new.payment_amount_kurus,new.method,new.collector_user_id,new.collected_at,new.operation_key)
    is distinct from row(old.id,old.order_id,old.payment_amount_kurus,old.method,old.collector_user_id,old.collected_at,old.operation_key) then
    raise exception using errcode = '23514', message = 'Payment correction requires an adjustment record';
  end if;
  return new;
end;
$$;
revoke all on function public.protect_payment_fact() from public, anon, authenticated;
create trigger protect_payment before update or delete on public.payments
  for each row execute function public.protect_payment_fact();

create function public.protect_item_snapshot() returns trigger
language plpgsql set search_path = '' as $$
begin
  if row(new.unit_price_kurus,new.discount_rate_snapshot,new.final_unit_price_kurus,
         new.conversion_to_base_snapshot,new.product_id,new.product_unit_id,new.unit)
    is distinct from row(old.unit_price_kurus,old.discount_rate_snapshot,old.final_unit_price_kurus,
         old.conversion_to_base_snapshot,old.product_id,old.product_unit_id,old.unit) then
    raise exception using errcode = '23514', message = 'Historical item snapshots cannot be repriced or substituted in place';
  end if;
  if new.quantity = old.quantity and new.line_total_kurus <> old.line_total_kurus then
    raise exception using errcode = '23514', message = 'Unchanged item quantity cannot be repriced';
  end if;
  return new;
end;
$$;
revoke all on function public.protect_item_snapshot() from public, anon, authenticated;
create trigger protect_item_snapshot before update on public.order_items
  for each row execute function public.protect_item_snapshot();

create function public.protect_decision_fact() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.status in ('approved','rejected','accepted') then
    raise exception using errcode = '23514', message = 'Completed decisions are immutable';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.protect_decision_fact() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['order_approvals','pricing_proposals','alternative_offers','stock_counts','order_change_requests'] loop
    execute format('create trigger protect_decision before update or delete on public.%I for each row execute function public.protect_decision_fact()',t);
  end loop;
end;
$$;
create function public.protect_assignment_history() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '23514', message = 'Assignment history cannot be deleted';
  end if;
  if old.closed_at is not null or row(new.id,new.run_id,new.order_id,new.assigned_by,new.assigned_at,new.previous_stop_id)
      is distinct from row(old.id,old.run_id,old.order_id,old.assigned_by,old.assigned_at,old.previous_stop_id) then
    raise exception using errcode = '23514', message = 'Reassignment requires closing the old assignment and inserting a new one';
  end if;
  return new;
end;
$$;
revoke all on function public.protect_assignment_history() from public, anon, authenticated;
create trigger protect_assignment before update or delete on public.delivery_stops
  for each row execute function public.protect_assignment_history();

-- Deny by default for EVERY new table, including salary and technical history.
do $$
declare t text;
begin
  foreach t in array array['categories','warehouses','vehicles','products','product_units',
    'product_price_history','pricing_rules','pricing_proposals','customer_pricing','orders',
    'order_items','order_status_history','order_approvals','order_change_requests','alternative_offers',
    'inventory','stock_counts','stock_count_items','inventory_movements','delivery_runs','delivery_stops',
    'driver_locations','delivery_confirmations','order_returns','order_return_items','payments',
    'payment_adjustments','ratings','employee_salary_records','notifications','app_settings','audit_logs'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
  end loop;
end;
$$;
create index orders_customer_idx on public.orders(customer_id);
create index order_items_order_idx on public.order_items(order_id);
create index payments_order_idx on public.payments(order_id);
create index inventory_movements_product_time_idx on public.inventory_movements(product_id,created_at);
create index notifications_user_idx on public.notifications(user_id);
comment on table public.driver_locations is 'Phase 12 skeleton only: no tracking, retention or location-based workflow.';
comment on table public.notifications is 'Phase 3 inbox schema only; no device tokens or push delivery.';
comment on table public.app_settings is 'Only default_payment_due_days: JSON integer 0..2147483647 days; no commercial default is seeded.';
comment on column public.orders.payment_status is 'Read/filter cache; future backend transactions synchronize from payments. No financial workflow in Phase 3.';
comment on column public.order_items.final_unit_price_kurus is 'Integer money snapshot; fractional discount rounding policy remains open. No pricing calculation in this migration.';
comment on column public.payments.operation_key is 'Unique per payment action, retained with the record. Duplicate inserts fail, replay response belongs to future transaction API.';
commit;
