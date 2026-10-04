-- Phase 3 closing review: seven approved integrity fixes only.
-- No workflow RPC, role policy, pricing formula or new business state.
begin;

-- 1. Approval freezes the count's detail, not only its header. Lock both
-- parents in UUID order when moving a detail so approval and editing serialize.
create function public.protect_approved_count_items() returns trigger
language plpgsql set search_path = '' as $$
declare
  parent_ids uuid[];
  parent_record record;
begin
  if tg_op = 'INSERT' then
    parent_ids := array[new.stock_count_id];
  elsif tg_op = 'DELETE' then
    parent_ids := array[old.stock_count_id];
  else
    parent_ids := array[old.stock_count_id, new.stock_count_id];
  end if;
  for parent_record in
    select id, status from public.stock_counts
    where id = any(parent_ids) order by id for update
  loop
    if parent_record.status = 'approved' then
      raise exception using errcode = '23514', message = 'Approved count items cannot be changed';
    end if;
  end loop;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.protect_approved_count_items() from public, anon, authenticated;
create trigger protect_approved_count_items before insert or update or delete on public.stock_count_items
  for each row execute function public.protect_approved_count_items();

-- 2. Sticky technical flag: clearing ended_at cannot unlock a historical run.
-- It is maintained by triggers, not a new business status or permission.
alter table public.delivery_runs
  add column vehicle_assignment_locked boolean not null default false;
update public.delivery_runs r set vehicle_assignment_locked = true
where r.ended_at is not null or exists (select 1 from public.delivery_stops s where s.run_id = r.id);

create function public.protect_run_vehicle() returns trigger
language plpgsql set search_path = '' as $$
declare
  was_locked boolean := false;
  has_assignments boolean;
begin
  select exists (select 1 from public.delivery_stops where run_id = new.id) into has_assignments;
  if tg_op = 'UPDATE' then
    was_locked := old.vehicle_assignment_locked or old.ended_at is not null or has_assignments;
    if new.vehicle_id is distinct from old.vehicle_id and was_locked then
      raise exception using errcode = '23514', message = 'Historical run vehicle is immutable; create a new run';
    end if;
  end if;
  new.vehicle_assignment_locked := was_locked or new.ended_at is not null or has_assignments;
  return new;
end;
$$;
revoke all on function public.protect_run_vehicle() from public, anon, authenticated;
create trigger protect_run_vehicle before insert or update on public.delivery_runs
  for each row execute function public.protect_run_vehicle();

create function public.lock_assigned_run_vehicle() returns trigger
language plpgsql set search_path = '' as $$
begin
  -- AFTER INSERT sees the new stop. Updating the parent serializes against
  -- concurrent vehicle edits; the run trigger keeps the flag true thereafter.
  update public.delivery_runs set vehicle_assignment_locked = true where id = new.run_id;
  return new;
end;
$$;
revoke all on function public.lock_assigned_run_vehicle() from public, anon, authenticated;
create trigger lock_assigned_run_vehicle after insert on public.delivery_stops
  for each row execute function public.lock_assigned_run_vehicle();
comment on column public.delivery_runs.vehicle_assignment_locked is
  'Trigger-maintained, irreversible vehicle lock after any assignment or recorded ended_at; not an authorization flag.';

-- 3. A party event is an actual confirmation; rejected/empty confirmations
-- cannot consume the party's unique slot. Existing finalizes_delivery check
-- still limits finalization to customer/resolution. Dual-party workflow and
-- actor authorization remain outside Phase 3.
alter table public.delivery_confirmations
  add constraint delivery_confirmation_driver_flag check (driver_confirmed = (event_type = 'driver')),
  add constraint delivery_confirmation_customer_flag check (customer_confirmed = (event_type = 'customer'));

-- 4. A snapshot belongs to its original order throughout its lifetime.
create function public.protect_item_order() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.order_id is distinct from old.order_id then
    raise exception using errcode = '23514', message = 'Order item cannot move to another order';
  end if;
  return new;
end;
$$;
revoke all on function public.protect_item_order() from public, anon, authenticated;
create trigger protect_item_order before update of order_id on public.order_items
  for each row execute function public.protect_item_order();

-- 5. Record who decided and when before the existing immutable-decision
-- trigger freezes an approved/rejected change request.
alter table public.order_change_requests
  add constraint order_change_decision_evidence check (
    status not in ('approved','rejected') or (decided_by is not null and decided_at is not null)
  );

-- 6. Predecessor links cannot cross orders or point to the new stop itself.
alter table public.delivery_stops
  add constraint delivery_stops_id_order_unique unique (id, order_id),
  drop constraint delivery_stops_previous_stop_id_fkey,
  add constraint delivery_stops_previous_same_order foreign key (previous_stop_id, order_id)
    references public.delivery_stops(id, order_id),
  add constraint delivery_stops_not_own_predecessor check (previous_stop_id is null or previous_stop_id <> id);

-- 7. A count adjustment references the counted product, and a compensation
-- references a movement of the same product. Existing nullability and delta
-- rules are unchanged; approval/workflow transactions are not implemented here.
alter table public.inventory_movements
  add constraint inventory_movements_id_product_unique unique (id, product_id),
  drop constraint inventory_movements_stock_count_id_fkey,
  add constraint inventory_movements_counted_product foreign key (stock_count_id, product_id)
    references public.stock_count_items(stock_count_id, product_id),
  drop constraint inventory_movements_compensates_movement_id_fkey,
  add constraint inventory_movements_compensates_same_product foreign key (compensates_movement_id, product_id)
    references public.inventory_movements(id, product_id);

commit;
