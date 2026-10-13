-- F15-01: read-only operational reports and Owner-only manual salary records.
begin;
alter table public.employee_salary_records
 add column revision integer not null default 0 check(revision>=0),
 add constraint salary_month_start check(extract(day from period)=1),
 add constraint salary_employee_month unique(employee_id,period);
-- Existing rows are preserved; no guessed amounts, month conversions or payroll.
create table private.salary_changes (
 id uuid primary key default gen_random_uuid(), record_id uuid not null references public.employee_salary_records(id),
 actor_id uuid not null references public.profiles(id), changed_at timestamptz not null default now(),
 reason text not null check(btrim(reason)<>''), old_record jsonb, new_record jsonb not null,
 request_key uuid not null unique, unique(record_id,request_key));
create table private.salary_receipts (
 request_key uuid primary key, actor_id uuid not null references public.profiles(id), payload jsonb not null,response jsonb not null);
alter table private.salary_changes enable row level security;
alter table private.salary_receipts enable row level security;
revoke all on private.salary_changes,private.salary_receipts from public,anon,authenticated;
create trigger salary_history_immutable before update or delete on private.salary_changes
 for each row execute function public.reject_fact_mutation();
alter table public.audit_logs drop constraint audit_logs_action_check;
alter table public.audit_logs add constraint audit_logs_action_check check(action in (
 'price_changed','stock_movement','stock_count_approved','order_status_changed','alternative_accepted','alternative_rejected',
 'payment_recorded','payment_corrected','payment_cancelled','credit_approved','credit_rejected','delivery_disputed',
 'delivery_resolved','role_changed','permission_changed','order_request_decided','payment_verified','credit_limit_changed',
 'dispatch_changed','salary_changed'));

create function public.management_report(start_day date,end_day date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare lo timestamptz; hi timestamptz; result jsonb;
begin
 if not coalesce(private.current_app_role() in ('manager','owner'),false) then
  raise exception using errcode='42501',message='Report access denied'; end if;
 if start_day is null or end_day is null or not isfinite(start_day) or not isfinite(end_day) or end_day<start_day then
  raise exception using errcode='22023',message='Valid date interval required'; end if;
 lo:=start_day::timestamp at time zone 'Europe/Istanbul';
 hi:=(end_day+1)::timestamp at time zone 'Europe/Istanbul';
 select jsonb_build_object(
  'start_day',start_day,'end_day',end_day,'as_of',statement_timestamp(),
  'orders',coalesce((select jsonb_agg(to_jsonb(x) order by x.status) from (
    select status,count(*) as count from public.orders where created_at>=lo and created_at<hi group by status) x),'[]'),
  'deliveries',(select jsonb_build_object('count',count(*),'total_kurus',coalesce(sum(o.total_kurus),0)::text)
    from public.orders o join lateral (select min(c.created_at) as finalized_at from public.delivery_confirmations c
      where c.order_id=o.id and c.finalizes_delivery) f on true
    where o.status='delivered' and private.delivery_finalized(o.id) and f.finalized_at>=lo and f.finalized_at<hi),
  'payments',coalesce((select jsonb_agg(to_jsonb(x) order by x.status) from (
    select verification_status as status,count(*) as count,sum(payment_amount_kurus)::text as total_kurus
    from public.payments where collected_at>=lo and collected_at<hi and verification_status in ('recorded','verified')
    group by verification_status) x),'[]'),
  'inventory',coalesce((select jsonb_agg(to_jsonb(x) order by x.name,x.product_id) from (
    select p.id as product_id,p.name,p.base_unit,i.physical_qty::text,i.reserved_qty::text,i.available_qty::text
    from public.inventory i join public.products p on p.id=i.product_id) x),'[]'),
  'ratings',coalesce((select jsonb_agg(to_jsonb(x) order by x.name,x.driver_id) from (
    select r.driver_id,p.name,count(*) as count,avg(r.score)::text as average,
      count(*) filter(where score=1) as stars_1,count(*) filter(where score=2) as stars_2,
      count(*) filter(where score=3) as stars_3,count(*) filter(where score=4) as stars_4,count(*) filter(where score=5) as stars_5
    from public.ratings r join public.profiles p on p.id=r.driver_id group by r.driver_id,p.name) x),'[]')
 ) into result;
 return result;
end; $$;

create function public.owner_salary_workspace(target_month date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if private.current_app_role() is distinct from 'owner' then raise exception using errcode='42501',message='Owner required'; end if;
 if target_month is null or not isfinite(target_month) or extract(day from target_month)<>1 then
  raise exception using errcode='22023',message='Month start required'; end if;
 return jsonb_build_object(
  'employees',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',active) order by name,id)
    from public.profiles where role<>'customer'),'[]'),
  'records',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'employee_id',s.employee_id,'name',p.name,
    'period',s.period,'salary_kurus',s.salary_kurus::text,'bonus_kurus',s.bonus_kurus::text,'revision',s.revision)
    order by p.name,s.id) from public.employee_salary_records s join public.profiles p on p.id=s.employee_id where s.period=target_month),'[]'),
  'history',coalesce((select jsonb_agg(to_jsonb(x) order by x.changed_at desc,x.id desc) from (
    select c.id,c.record_id,c.actor_id,c.changed_at,c.reason,c.old_record,c.new_record
    from private.salary_changes c join public.employee_salary_records s on s.id=c.record_id where s.period=target_month
    order by c.changed_at desc,c.id desc limit 100) x),'[]'));
end; $$;

create function public.save_salary(target_employee uuid,target_month date,salary_kurus bigint,bonus_kurus bigint,
 reason text,expected_revision integer,request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous private.salary_receipts; old_row public.employee_salary_records; new_row public.employee_salary_records;
 payload jsonb:=jsonb_build_object('employee',target_employee,'month',target_month,'salary',salary_kurus,'bonus',bonus_kurus,
  'reason',reason,'revision',expected_revision); result jsonb; old_json jsonb;
begin
 perform 1 from auth.users where id=auth.uid() for share;
 perform 1 from public.profiles where id=auth.uid() for share;
 if private.current_app_role() is distinct from 'owner' then raise exception using errcode='42501',message='Owner required'; end if;
 if request_key is null then raise exception using errcode='22023',message='Key required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,73015));
 select * into previous from private.salary_receipts r where r.request_key=save_salary.request_key;
 if found then
  if previous.actor_id<>auth.uid() or previous.payload<>payload then raise exception using errcode='22023',message='Key payload mismatch'; end if;
  return previous.response;
 end if;
 if target_employee is null or target_month is null or not isfinite(target_month) or extract(day from target_month)<>1
  or salary_kurus is null or salary_kurus<0 or bonus_kurus is null or bonus_kurus<0 or expected_revision is null
  or expected_revision < -1 or nullif(btrim(reason),'') is null then
  raise exception using errcode='22023',message='Employee month amounts reason and revision required'; end if;
 perform 1 from public.profiles where id=target_employee and role<>'customer' for share;
 if not found then raise exception using errcode='22023',message='Employee required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(target_employee::text||target_month::text,73015));
 select * into old_row from public.employee_salary_records where employee_id=target_employee and period=target_month for update;
 if coalesce(old_row.revision,-1)<>expected_revision then raise exception using errcode='40001',message='Salary changed; reload'; end if;
 if old_row.id is null then
  insert into public.employee_salary_records(employee_id,period,salary_kurus,bonus_kurus,created_by)
  values(target_employee,target_month,save_salary.salary_kurus,save_salary.bonus_kurus,auth.uid()) returning * into new_row;
 else
  old_json:=to_jsonb(old_row);
  update public.employee_salary_records set salary_kurus=save_salary.salary_kurus,bonus_kurus=save_salary.bonus_kurus,
    revision=revision+1 where id=old_row.id returning * into new_row;
 end if;
 insert into private.salary_changes(record_id,actor_id,reason,old_record,new_record,request_key)
 values(new_row.id,auth.uid(),reason,old_json,to_jsonb(new_row),request_key);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data,operation_key)
 values(auth.uid(),'salary_changed','employee_salary_record',new_row.id,old_json,to_jsonb(new_row)||jsonb_build_object('reason',reason),request_key);
 result:=jsonb_build_object('id',new_row.id,'revision',new_row.revision);
 insert into private.salary_receipts values(request_key,auth.uid(),payload,result);
 return result;
end; $$;

create function public.owner_audit_page(before_time timestamptz default null,before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if private.current_app_role() is distinct from 'owner' then raise exception using errcode='42501',message='Owner required'; end if;
 if (before_time is null)<>(before_id is null) then raise exception using errcode='22023',message='Complete cursor required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id desc) from (
  select a.id,a.actor_id,p.name as actor_name,a.action,a.entity_type,a.entity_id,a.created_at
  from public.audit_logs a join public.profiles p on p.id=a.actor_id
  where before_time is null or (a.created_at,a.id)<(before_time,before_id)
  order by a.created_at desc,a.id desc limit 50) x),'[]');
end; $$;
revoke all on function public.management_report(date,date),public.owner_salary_workspace(date),
 public.save_salary(uuid,date,bigint,bigint,text,integer,uuid),public.owner_audit_page(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.management_report(date,date),public.owner_salary_workspace(date),
 public.save_salary(uuid,date,bigint,bigint,text,integer,uuid),public.owner_audit_page(timestamptz,uuid) to authenticated;
commit;
