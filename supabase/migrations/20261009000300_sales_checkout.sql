-- Phase 7: latest user decision narrows Sales to active assigned customers.
begin;
create or replace function private.sales_customer(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce(private.current_app_role()='sales_operator' and exists(
  select 1 from public.customers c where c.id=target and c.active
   and c.assigned_sales_operator_id=(select auth.uid())
 ),false);
$$;
-- Existing customer/order/pricing policies and checkout call this helper.
-- No creator exception, new write grant, pricing formula or workflow is added.
create function public.sales_checkout_customers() returns table(id uuid,company_name text)
language plpgsql stable security definer set search_path='' as $$
begin
 if private.current_app_role() is distinct from 'sales_operator'::public.app_role then
  raise exception using errcode='42501',message='Sales customer selection denied';
 end if;
 return query select c.id,c.company_name from public.customers c
  where private.sales_customer(c.id) order by c.company_name,c.id;
end;
$$;
revoke all on function public.sales_checkout_customers() from public,anon,authenticated;
grant execute on function public.sales_checkout_customers() to authenticated;
commit;
