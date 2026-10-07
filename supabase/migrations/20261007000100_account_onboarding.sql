-- F4-05: verified customer signup, scoped invitations and reversible activation.
begin;
create table private.account_invitations (
  id uuid primary key default gen_random_uuid(),
  email text not null check(email=lower(btrim(email)) and position('@' in email)>1),
  name text not null check(btrim(name)<>''),
  role public.app_role not null,
  customer_id uuid references public.customers(id),
  invited_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '24 hours',
  revoked boolean not null default false,
  accepted_by uuid references public.profiles(id),
  accepted_at timestamptz,
  check((role='customer')=(customer_id is not null)),
  check((accepted_by is null)=(accepted_at is null))
);
alter table private.account_invitations enable row level security;
revoke all on private.account_invitations from public,anon,authenticated;
create unique index invitation_pending_email on private.account_invitations(email)
  where not revoked and accepted_at is null;

create function private.has_open_work(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.customers where assigned_sales_operator_id=target)
 or exists(select 1 from public.delivery_runs r
   where (r.primary_driver_id=target or r.assistant_driver_id=target)
    and (r.ended_at is null or exists(select 1 from public.delivery_stops s where s.run_id=r.id and s.closed_at is null)));
$$;

-- Trigger fires only on the explicit self-registration intent. Metadata cannot
-- choose a role or existing customer. Invite identities have no such intent.
create function private.register_customer_identity() returns trigger
language plpgsql security definer set search_path='' as $$
declare company text; person text; organization uuid;
begin
 if new.raw_user_meta_data->>'signup_type' is distinct from 'customer' then return new; end if;
 perform pg_advisory_xact_lock(hashtextextended(lower(new.email),73004));
 if exists(select 1 from private.account_invitations where email=lower(new.email)
   and not revoked and accepted_at is null and expires_at>now()) then
   raise exception using errcode='42501',message='Use the pending invitation';
 end if;
 company:=btrim(new.raw_user_meta_data->>'company'); person:=btrim(new.raw_user_meta_data->>'name');
 if coalesce(length(company),0) not between 1 and 200 or coalesce(length(person),0) not between 1 and 200 then
   raise exception using errcode='22023',message='Name and company required';
 end if;
 insert into public.profiles(id,role,name,email) values(new.id,'customer',person,new.email);
 insert into public.customers(company_name,contact_name,email,created_by)
   values(company,person,new.email,new.id) returning id into organization;
 insert into public.customer_users(customer_id,user_id) values(organization,new.id);
 return new;
end;
$$;
create trigger register_customer_identity after insert on auth.users
 for each row execute function private.register_customer_identity();

create function public.create_account_invitation(invitee_email text,display_name text,
 target_role public.app_role,target_customer uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); actor_role public.app_role; result uuid; normalized text:=lower(btrim(invitee_email));
begin
 perform 1 from public.profiles where id=actor for update;
 actor_role:=private.current_app_role();
 if actor_role is null or actor_role not in ('owner','manager') or
   (actor_role='manager' and target_role in ('owner','manager','accounting')) then
   raise exception using errcode='42501',message='Invitation denied';
 end if;
 if normalized is null or position('@' in normalized)<2 or length(normalized)>254 or
   coalesce(length(btrim(display_name)),0) not between 1 and 200 or target_role is null then
   raise exception using errcode='22023',message='Valid invitation fields required';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(normalized,73004));
 if exists(select 1 from auth.users u join public.profiles p on p.id=u.id where lower(u.email)=normalized) then
   raise exception using errcode='22023',message='Existing accounts use role/membership administration';
 end if;
 if (target_role='customer') is distinct from (target_customer is not null) then
   raise exception using errcode='22023',message='Customer invitation requires an explicit organization';
 end if;
 if target_customer is not null then
   perform 1 from public.customers where id=target_customer and active for update;
   if not found or exists(select 1 from public.customer_users where customer_id=target_customer) then
     raise exception using errcode='22023',message='Empty active organization required';
   end if;
 end if;
 update private.account_invitations set revoked=true where email=normalized and expires_at<=now() and accepted_at is null;
 insert into private.account_invitations(email,name,role,customer_id,invited_by)
   values(normalized,btrim(display_name),target_role,target_customer,actor) returning id into result;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data)
  values(actor,'permission_changed','account_invitation',result,jsonb_build_object('role',target_role,'customer_id',target_customer));
 return result;
end;
$$;
create function public.revoke_account_invitation(invitation_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare invitation private.account_invitations;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 select * into invitation from private.account_invitations where id=invitation_id for update;
 if not found or not coalesce(private.current_app_role()='owner' or
   (private.current_app_role()='manager' and invitation.invited_by=auth.uid() and invitation.role in ('customer','sales_operator','warehouse','driver')),false) then
  raise exception using errcode='42501',message='Invitation revocation denied';
 end if;
 if invitation.accepted_at is not null then raise exception using errcode='22023',message='Invitation already accepted'; end if;
 update private.account_invitations set revoked=true where id=invitation_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data)
   values(auth.uid(),'permission_changed','account_invitation',invitation_id,jsonb_build_object('revoked',true));
end;
$$;
create function public.account_invitations()
returns table(id uuid,email text,name text,role public.app_role,expires_at timestamptz,revoked boolean,accepted_at timestamptz)
language sql stable security definer set search_path='' as $$
 select i.id,i.email,i.name,i.role,i.expires_at,i.revoked,i.accepted_at from private.account_invitations i
 where private.current_app_role()='owner' or (private.current_app_role()='manager' and i.invited_by=auth.uid());
$$;
-- Only the verified caller's completion state; no profile/role data is exposed.
-- Works for disabled profiles too, so a replay never writes a new credential.
create function public.account_invitation_accepted() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.account_invitations i join auth.users u on u.id=i.accepted_by
   where u.id=auth.uid() and u.email_confirmed_at is not null and i.accepted_at is not null
     and i.email=lower(u.email));
$$;
create function public.accept_account_invitation() returns void
language plpgsql security definer set search_path='' as $$
declare invitation private.account_invitations; actor uuid:=auth.uid(); verified_email text; inviter_role public.app_role;
begin
 select lower(email) into verified_email from auth.users where id=actor and email_confirmed_at is not null;
 if verified_email is null then raise exception using errcode='42501',message='Verified email required'; end if;
 -- Find candidate before locks; then re-read under locks. Role/profile checks are live.
 select * into invitation from private.account_invitations where email=verified_email and not revoked
   and (accepted_at is null or accepted_by=actor) order by created_at desc limit 1;
 if not found then raise exception using errcode='42501',message='Invitation unavailable'; end if;
 perform 1 from auth.users where id in (actor,invitation.invited_by) order by id for update;
 perform 1 from public.profiles where id in (actor,invitation.invited_by) order by id for update;
 select * into invitation from private.account_invitations where id=invitation.id for update;
 if invitation.revoked or (invitation.accepted_at is null and invitation.expires_at<=now()) then
   raise exception using errcode='42501',message='Invitation unavailable';
 end if;
 if invitation.accepted_by=actor then return; end if;
 if invitation.accepted_at is not null or exists(select 1 from public.profiles where id=actor) then
   raise exception using errcode='42501',message='Account already provisioned';
 end if;
 select role into inviter_role from public.profiles where id=invitation.invited_by and active;
 if inviter_role is null or inviter_role not in ('owner','manager') or
   (inviter_role='manager' and invitation.role in ('owner','manager','accounting')) then
   raise exception using errcode='42501',message='Inviter authority no longer valid';
 end if;
 if invitation.customer_id is not null then
   perform 1 from public.customers where id=invitation.customer_id and active for update;
   if not found or exists(select 1 from public.customer_users where customer_id=invitation.customer_id) then
     raise exception using errcode='22023',message='Destination no longer available';
   end if;
 end if;
 insert into public.profiles(id,role,name,email) values(actor,invitation.role,invitation.name,verified_email);
 if invitation.customer_id is not null then
   insert into public.customer_users(customer_id,user_id) values(invitation.customer_id,actor);
 end if;
 update private.account_invitations set accepted_by=actor,accepted_at=now() where id=invitation.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_data)
   values(invitation.invited_by,'role_changed','profile',actor,jsonb_build_object('role',invitation.role,'invitation_id',invitation.id));
end;
$$;

create function private.preserve_last_owner() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.role='owner' and old.active and (not new.active or new.role<>'owner') then
   perform pg_advisory_xact_lock(73005);
   if not exists(select 1 from public.profiles where role='owner' and active and id<>old.id) then
     raise exception using errcode='55000',message='Last active Owner must remain';
   end if;
 end if;
 return new;
end;
$$;
create trigger preserve_last_owner before update of role,active on public.profiles
 for each row execute function private.preserve_last_owner();
create function public.set_account_active(target_user uuid,enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
declare old_active boolean; target_role public.app_role;
begin
 perform 1 from auth.users where id in (auth.uid(),target_user) order by id for update;
 perform 1 from public.profiles where id in (auth.uid(),target_user) order by id for update;
 if private.current_app_role() is distinct from 'owner' then
   raise exception using errcode='42501',message='Only Owner may change activation';
 end if;
 select active,role into old_active,target_role from public.profiles where id=target_user;
 if not found or enabled is null then raise exception using errcode='22023',message='Account and activation required'; end if;
 if not enabled and target_role<>'customer' and private.has_open_work(target_user) then
   raise exception using errcode='55000',message='Open work assignments must be closed first';
 end if;
 if old_active=enabled then return; end if;
 update public.profiles set active=enabled where id=target_user;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_data,new_data)
   values(auth.uid(),'permission_changed','profile',target_user,
     jsonb_build_object('active',old_active),jsonb_build_object('active',enabled));
end;
$$;
revoke all on function private.has_open_work(uuid),private.register_customer_identity(),private.preserve_last_owner() from public,anon,authenticated;
revoke all on function public.create_account_invitation(text,text,public.app_role,uuid),
 public.revoke_account_invitation(uuid),public.account_invitations(),public.accept_account_invitation(),
 public.account_invitation_accepted(),public.set_account_active(uuid,boolean) from public,anon,authenticated;
grant execute on function public.create_account_invitation(text,text,public.app_role,uuid),
 public.revoke_account_invitation(uuid),public.account_invitations(),public.accept_account_invitation(),
 public.account_invitation_accepted(),public.set_account_active(uuid,boolean) to authenticated;
commit;
