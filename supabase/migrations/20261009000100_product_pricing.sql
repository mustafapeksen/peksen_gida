-- Phase 5. No cart, order creation, reservation or quarterly proposal workflow.
begin;

-- A Warehouse-created draft has no price. Zero is a real price, not a sentinel.
alter table public.products alter column unit_price_kurus drop not null;
alter table public.products add constraint active_product_has_price check (not active or unit_price_kurus is not null);
alter table public.product_price_history alter column old_price_kurus drop not null;

-- Preserve historical integer snapshots. New calculations retain exact sale-unit
-- prices separately; legacy integer fields are rounded display snapshots only.
alter table public.order_items
  add column exact_list_price_kurus_snapshot numeric,
  add column exact_final_price_kurus_snapshot numeric,
  add constraint exact_price_snapshot_consistency check (
    (exact_list_price_kurus_snapshot is null and exact_final_price_kurus_snapshot is null)
    or (exact_list_price_kurus_snapshot is not null and exact_final_price_kurus_snapshot is not null
      and exact_list_price_kurus_snapshot >= 0 and exact_list_price_kurus_snapshot < 'Infinity'::numeric
      and exact_final_price_kurus_snapshot = exact_list_price_kurus_snapshot * (1-discount_rate_snapshot)
      and unit_price_kurus = round(exact_list_price_kurus_snapshot)
      and final_unit_price_kurus = round(exact_final_price_kurus_snapshot)
      and line_total_kurus = round(exact_final_price_kurus_snapshot * quantity)));

create function private.protect_exact_price_snapshot() returns trigger
language plpgsql set search_path = '' as $$
begin
  if row(new.exact_list_price_kurus_snapshot,new.exact_final_price_kurus_snapshot)
    is distinct from row(old.exact_list_price_kurus_snapshot,old.exact_final_price_kurus_snapshot) then
    raise exception using errcode='23514', message='Exact price snapshots are immutable';
  end if;
  return new;
end;
$$;
revoke all on function private.protect_exact_price_snapshot() from public,anon,authenticated;
create trigger protect_exact_price_snapshot before update on public.order_items
  for each row execute function private.protect_exact_price_snapshot();

-- Reuse the approved Phase 4 read matrix, including Warehouse's price exclusion.
-- NUMERIC/BIGINT leave the API as text, never a JSON floating point value.
create function public.product_reference_list() returns setof jsonb
language plpgsql stable security definer set search_path = '' as $$
declare actor_role public.app_role := private.current_app_role();
begin
  if actor_role is null or actor_role not in ('warehouse','manager','owner') then
    raise exception using errcode='42501',message='Product access denied';
  end if;
  return query select jsonb_build_object('id',p.id,'sku',p.sku,'name',p.name,
    'package_label',p.package_label,'base_unit',p.base_unit,'active',p.active,
    'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.unit_name,
      'conversion',u.conversion_to_base::text,'orderable',u.orderable) order by u.unit_name)
      from public.product_units u where u.product_id=p.id),'[]'::jsonb))
    || case when actor_role in ('manager','owner') then jsonb_build_object(
      'price_kurus',p.unit_price_kurus::text,'minimum',p.min_quantity::text,'category',c.name)
      else '{}'::jsonb end
    from public.products p join public.categories c on c.id=p.category_id order by p.name,p.id;
end;
$$;

create function public.product_price_events(target_product uuid) returns setof jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if private.current_app_role() is null or private.current_app_role() not in ('manager','owner') then
    raise exception using errcode='42501',message='Price access denied';
  end if;
  return query select jsonb_build_object('old_price',h.old_price_kurus::text,
    'new_price',h.new_price_kurus::text,'reason',h.reason,'actor',p.name,'at',h.created_at)
    from public.product_price_history h join public.profiles p on p.id=h.changed_by
    where h.product_id=target_product order by h.created_at desc,h.id;
end;
$$;

create function public.change_product_price(target_product uuid, expected_price bigint,
  new_price bigint, change_reason text, request_key uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); old_price bigint; event public.product_price_history; event_id uuid;
begin
  -- Share the identity administration lock, then operation key, then product.
  perform 1 from auth.users where id=actor for share;
  if private.current_app_role() is null or private.current_app_role() not in ('manager','owner') then
    raise exception using errcode='42501',message='Price mutation denied';
  end if;
  if new_price is null or new_price < 0 or request_key is null or nullif(btrim(change_reason),'') is null then
    raise exception using errcode='22023',message='Invalid price change';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('price:'||request_key::text,0));
  select * into event from public.product_price_history where operation_key=request_key;
  if found then
    if event.product_id is distinct from target_product or event.new_price_kurus <> new_price
      or event.old_price_kurus is distinct from expected_price or event.changed_by <> actor
      or event.reason <> btrim(change_reason) then
      raise exception using errcode='22023',message='Operation key payload conflict';
    end if;
    return event.id;
  end if;
  select p.unit_price_kurus into old_price from public.products p where p.id=target_product for update;
  if not found then raise exception using errcode='22023',message='Product not found'; end if;
  if old_price is distinct from expected_price then
    raise exception using errcode='40001',message='Price changed; reload before retry';
  end if;
  if old_price = new_price then raise exception using errcode='22023',message='Price is unchanged'; end if;
  update public.products set unit_price_kurus=new_price where id=target_product;
  insert into public.product_price_history(product_id,old_price_kurus,new_price_kurus,changed_by,reason,operation_key)
    values(target_product,old_price,new_price,actor,btrim(change_reason),request_key) returning id into event_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
    values(actor,'price_changed','products',target_product,jsonb_build_object('unit_price_kurus',old_price),
      jsonb_build_object('unit_price_kurus',new_price,'reason',btrim(change_reason)),request_key);
  return event_id;
end;
$$;

create function public.product_categories() returns table(id uuid,name text)
language sql stable security definer set search_path = '' as $$
  select c.id,c.name from public.categories c where c.active
    and private.current_app_role() in ('warehouse','manager','owner') order by c.name;
$$;

create function public.create_product_draft(product_id uuid, product_sku text, product_name text,
  category uuid, base_unit_name text, minimum_quantity integer, package_text text, sales_units jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare u jsonb;
begin
  perform 1 from auth.users where id=auth.uid() for share;
  if private.current_app_role() is null or private.current_app_role() not in ('warehouse','manager','owner') then
    raise exception using errcode='42501',message='Product creation denied';
  end if;
  if product_id is null or nullif(btrim(product_sku),'') is null or nullif(btrim(product_name),'') is null
    or nullif(btrim(base_unit_name),'') is null or minimum_quantity is null or minimum_quantity <= 0
    or sales_units is null or jsonb_typeof(sales_units) <> 'array' then
    raise exception using errcode='22023',message='Invalid product';
  end if;
  if jsonb_array_length(sales_units)=0 then raise exception using errcode='22023',message='Sales unit required'; end if;
  perform 1 from public.categories where id=category and active for share;
  if not found then raise exception using errcode='22023',message='Active category required'; end if;
  insert into public.products(id,sku,name,category_id,base_unit,min_quantity,package_label,unit_price_kurus,active)
    values(product_id,btrim(product_sku),btrim(product_name),category,btrim(base_unit_name),minimum_quantity,
      nullif(btrim(package_text),''),null,false);
  for u in select value from jsonb_array_elements(sales_units) loop
    if jsonb_typeof(u) <> 'object' or nullif(btrim(u->>'name'),'') is null
      or jsonb_typeof(u->'conversion') is distinct from 'string'
      or (u->>'conversion') !~ '^[0-9]+([.][0-9]+)?$'
      or (u->>'conversion')::numeric <= 0 then
      raise exception using errcode='22023',message='Positive exact decimal conversion required';
    end if;
    if btrim(u->>'name')=btrim(base_unit_name) and (u->>'conversion')::numeric <> 1 then
      raise exception using errcode='22023',message='Base unit conversion must be one';
    end if;
    insert into public.product_units(product_id,unit_name,conversion_to_base,orderable)
      values(product_id,btrim(u->>'name'),(u->>'conversion')::numeric,true);
  end loop;
  return product_id;
end;
$$;

create function public.activate_product(target_product uuid, expected_price bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare p public.products;
begin
  perform 1 from auth.users where id=auth.uid() for share;
  if private.current_app_role() is null or private.current_app_role() not in ('manager','owner') then
    raise exception using errcode='42501',message='Product activation denied';
  end if;
  select * into p from public.products where id=target_product for update;
  if not found or p.unit_price_kurus is null then
    raise exception using errcode='22023',message='Priced product required';
  end if;
  if p.unit_price_kurus is distinct from expected_price then
    raise exception using errcode='40001',message='Price changed; reload before activation';
  end if;
  if not exists(select 1 from public.categories where id=p.category_id and active)
    or not exists(select 1 from public.product_units where product_id=p.id and orderable) then
    raise exception using errcode='22023',message='Active category and sales unit required';
  end if;
  update public.products set active=true where id=p.id;
end;
$$;

-- Shared backend price read for Customer, assigned/creator Sales, Manager/Owner.
-- It does not create an order or reserve stock. No client price/discount accepted.
create function public.quote_product(target_customer uuid, target_unit uuid, sale_quantity integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p public.products; u public.product_units; rate numeric := 0; base_qty numeric;
  exact_list numeric; exact_final numeric; line_total numeric; subtotal numeric;
begin
  if not coalesce(private.current_app_role() in ('manager','owner')
    or private.owns_customer(target_customer) or private.sales_customer(target_customer),false) then
    raise exception using errcode='42501',message='Customer pricing access denied';
  end if;
  if not exists(select 1 from public.customers where id=target_customer and active)
    or sale_quantity is null or sale_quantity <= 0 then
    raise exception using errcode='22023',message='Active customer and positive integer quantity required';
  end if;
  select * into u from public.product_units where id=target_unit and orderable;
  if not found then raise exception using errcode='22023',message='Orderable unit required'; end if;
  select * into p from public.products where id=u.product_id and active and unit_price_kurus is not null;
  if not found or not exists(select 1 from public.categories where id=p.category_id and active) then
    raise exception using errcode='22023',message='Product not for sale';
  end if;
  base_qty := sale_quantity::numeric * u.conversion_to_base;
  if base_qty < p.min_quantity then raise exception using errcode='22023',message='Below product base-unit minimum'; end if;
  select cp.discount_rate into rate from public.customer_pricing cp
    where cp.customer_id=target_customer and cp.effective_from <= (statement_timestamp() at time zone 'Europe/Istanbul')::date;
  rate := coalesce(rate,0);
  exact_list := p.unit_price_kurus::numeric * u.conversion_to_base;
  exact_final := exact_list * (1-rate);
  subtotal := round(exact_list * sale_quantity);
  line_total := round(exact_final * sale_quantity);
  if greatest(subtotal,line_total,round(exact_list)) > 9223372036854775807::numeric then
    raise exception using errcode='22003',message='Money storage range exceeded';
  end if;
  return jsonb_build_object('product_id',p.id,'product_unit_id',u.id,'unit',u.unit_name,
    'quantity',sale_quantity,'conversion_to_base_snapshot',u.conversion_to_base::text,'base_quantity',base_qty::text,
    'unit_price_kurus',round(exact_list)::text,'discount_rate_snapshot',rate::text,
    'final_unit_price_kurus',round(exact_final)::text,'line_total_kurus',line_total::text,
    'exact_list_price_kurus_snapshot',exact_list::text,'exact_final_price_kurus_snapshot',exact_final::text,
    'subtotal_kurus',subtotal::text,'discount_total_kurus',(subtotal-line_total)::text);
end;
$$;

revoke all on function public.product_categories(),public.create_product_draft(uuid,text,text,uuid,text,integer,text,jsonb),
  public.activate_product(uuid,bigint),public.quote_product(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.product_categories(),public.create_product_draft(uuid,text,text,uuid,text,integer,text,jsonb),
  public.activate_product(uuid,bigint),public.quote_product(uuid,uuid,integer) to authenticated;

revoke all on function public.product_reference_list(),public.product_price_events(uuid),
  public.change_product_price(uuid,bigint,bigint,text,uuid) from public,anon,authenticated;
grant execute on function public.product_reference_list(),public.product_price_events(uuid),
  public.change_product_price(uuid,bigint,bigint,text,uuid) to authenticated;
commit;
