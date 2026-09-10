-- County ownership is independent of a vehicle's GPS position and display name.
-- Validated against a local PostgreSQL copy of the production schema, including
-- RLS, triggers, QR RPCs, legacy OSP upsert payloads and two-county denial tests.
-- Fail fast instead of waiting on operational writes; apply as one transaction.
set local lock_timeout='3s';
set local statement_timeout='30s';
create table public.firemap_counties (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check(slug ~ '^[a-z0-9][a-z0-9-]{2,59}$'),
 province text not null, name text not null, default_area jsonb not null,
 created_at timestamptz not null default now(), unique(province,name)
);
alter table public.firemap_counties enable row level security;
revoke all on public.firemap_counties from anon,authenticated;
grant select on public.firemap_counties to anon,authenticated;
grant all on public.firemap_counties to service_role;
create policy "public county directory" on public.firemap_counties for select to anon,authenticated using(true);
create table public.firemap_platform_admins(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.firemap_platform_admins enable row level security;
revoke all on public.firemap_platform_admins from anon,authenticated;
grant select on public.firemap_platform_admins to authenticated;
grant all on public.firemap_platform_admins to service_role;
create policy "read own platform permission" on public.firemap_platform_admins for select to authenticated using(user_id=auth.uid());
insert into public.firemap_platform_admins select a.user_id from public.firemap_accounts a join auth.users u on u.id=a.user_id where u.email='sk@firemap.local' and a.role='SK' and a.enabled;

alter table public.firemap_accounts add column county_id uuid references public.firemap_counties(id),add column login_email text;
create index firemap_accounts_county_idx on public.firemap_accounts(county_id);
create unique index firemap_one_sk_per_county on public.firemap_accounts(county_id) where role='SK';
insert into public.firemap_counties(slug,province,name,default_area) values('lodzkie-radomszczanski','Łódzkie','powiat radomszczański','{"province":"Łódzkie","county":"powiat radomszczański","center":[51.067,19.445],"bounds":[[50.58,18.55],[51.55,20.48]]}');
-- All existing operational accounts were verified as the original Radomsko deployment.
update public.firemap_accounts a set county_id=c.id,login_email=u.email from public.firemap_counties c,auth.users u where c.slug='lodzkie-radomszczanski' and u.id=a.user_id;
create or replace function public.firemap_county_id() returns uuid language sql stable security definer set search_path='' as $$select county_id from public.firemap_accounts where user_id=auth.uid() and enabled$$;
revoke all on function public.firemap_county_id() from public,anon;
grant execute on function public.firemap_county_id() to authenticated,service_role;
create policy "SK read county accounts" on public.firemap_accounts for select to authenticated using(public.firemap_is_sk() and county_id=public.firemap_county_id());
alter table public.incidents add column county_id uuid references public.firemap_counties(id) default public.firemap_county_id();
update public.incidents i set county_id=a.county_id from public.firemap_accounts a where a.user_id=i.sztab_id or (i.sztab_id is null and a.login_email=i.created_by);
create index incidents_county_idx on public.incidents(county_id);
alter table public.vehicles add column county_id uuid references public.firemap_counties(id),add column account_id uuid references public.firemap_accounts(user_id);
update public.vehicles v set account_id=a.user_id,county_id=a.county_id from public.firemap_accounts a where v.external_session_id is null and v.unit_name=a.unit_name and a.role in ('UNIT','JRG');
update public.vehicles v set county_id=i.county_id from public.incidents i where v.incident_id=i.id and v.external_session_id is not null;
-- Preserve unmapped legacy rows in their original county; claim them only by matching account name.
update public.vehicles set county_id=(select id from public.firemap_counties where slug='lodzkie-radomszczanski') where county_id is null and external_session_id is null;
create index vehicles_county_idx on public.vehicles(county_id);
create index vehicles_account_idx on public.vehicles(account_id);

create or replace function public.firemap_can_view_incident(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.incidents i join public.firemap_accounts a on a.user_id=auth.uid() where i.id=p_id and a.enabled and case when a.role='SZTAB' then i.sztab_id=a.user_id else i.county_id=a.county_id end)
$$;
create or replace function public.firemap_can_manage_incident(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.incidents i join public.firemap_accounts a on a.user_id=auth.uid() where i.id=p_id and a.enabled and ((a.role='SK' and a.county_id=i.county_id) or (a.role='SZTAB' and i.sztab_id=a.user_id)))
$$;
revoke all on function public.firemap_can_view_incident(uuid),public.firemap_can_manage_incident(uuid) from public,anon;
grant execute on function public.firemap_can_view_incident(uuid),public.firemap_can_manage_incident(uuid) to authenticated,service_role;
create policy "county incident scope" on public.incidents as restrictive for all to authenticated
using(county_id=(select public.firemap_county_id()))
with check(county_id=(select public.firemap_county_id()));
create policy "county drawings scope" on public.incident_drawings as restrictive for all to authenticated
using(public.firemap_can_view_incident(incident_id)) with check(public.firemap_can_view_incident(incident_id));
create policy "county code scope" on public.incident_join_codes as restrictive for select to authenticated using(public.firemap_can_manage_incident(incident_id));
create policy "county session scope" on public.external_force_sessions as restrictive for select to authenticated using(public.firemap_can_manage_incident(incident_id));
create policy "county vehicle scope" on public.vehicles as restrictive for select to authenticated
using(county_id=(select public.firemap_county_id()) or public.firemap_can_view_incident(incident_id));

-- Bind every authenticated position write to its real account. Guest RPCs run as owner.
create or replace function public.firemap_bind_vehicle_owner() returns trigger language plpgsql security invoker set search_path='' as $$
declare a public.firemap_accounts%rowtype;
begin
 if current_user in ('postgres','service_role','supabase_admin') then
  if new.external_session_id is not null then select i.county_id into new.county_id from public.external_force_sessions s join public.incidents i on i.id=s.incident_id where s.id=new.external_session_id and s.vehicle_id=new.id;end if;
  return new;
 end if;
 select * into a from public.firemap_accounts where user_id=auth.uid() and enabled;
 if a.user_id is null or a.county_id is null then raise exception 'Brak przypisania konta do powiatu';end if;
 if a.role in ('UNIT','JRG') then
  if tg_op='UPDATE' and not (old.account_id=a.user_id or (old.account_id is null and old.external_session_id is null and old.county_id=a.county_id and old.unit_name=a.unit_name)) then raise exception 'To pojazd innej jednostki';end if;
  if new.external_session_id is not null then raise exception 'Użyj kodu QR do sesji zewnętrznej';end if;
  new.account_id:=a.user_id;new.county_id:=a.county_id;
 elsif a.role='SK' and tg_op='UPDATE' then
  new.account_id:=old.account_id;new.county_id:=old.county_id;
  if new.external_session_id is distinct from old.external_session_id then raise exception 'Nie można zmienić sesji zastępu';end if;
 else raise exception 'Brak uprawnień do zapisu pozycji';end if;
 if new.incident_id is not null and not public.firemap_can_view_incident(new.incident_id) then raise exception 'Brak dostępu do zdarzenia';end if;
 return new;
end $$;
revoke all on function public.firemap_bind_vehicle_owner() from public,anon,authenticated;
create trigger firemap_vehicle_owner before insert or update on public.vehicles for each row execute function public.firemap_bind_vehicle_owner();
drop policy "public insert vehicles" on public.vehicles;
drop policy "public update vehicles" on public.vehicles;
drop policy "public delete vehicles" on public.vehicles;
create policy "account insert own vehicle" on public.vehicles for insert to authenticated with check(account_id=auth.uid() and county_id=public.firemap_county_id() and lat between -90 and 90 and lng between -180 and 180);
create policy "account update own vehicle or county SK" on public.vehicles for update to authenticated
using(account_id=auth.uid() or (county_id=public.firemap_county_id() and public.firemap_is_sk()))
with check(county_id=public.firemap_county_id() and (account_id=auth.uid() or public.firemap_is_sk()) and lat between -90 and 90 and lng between -180 and 180);
create policy "account delete own vehicle or county SK" on public.vehicles for delete to authenticated using(account_id=auth.uid() or (county_id=public.firemap_county_id() and public.firemap_is_sk()));

-- Keep the tested code allocator, but scope its SECURITY DEFINER authorization.
do $$declare d text;begin
 select pg_get_functiondef('public.create_incident_join_code(uuid,integer)'::regprocedure) into d;
 d:=regexp_replace(d,'if auth.uid\(\) is null or not .* then raise exception ''Brak dostępu do tego zdarzenia'';end if;','if not public.firemap_can_manage_incident(p_incident_id) then raise exception ''Brak dostępu do tego zdarzenia'';end if;');
 if position('if not public.firemap_can_manage_incident(p_incident_id)' in d)=0 then raise exception 'Unexpected allocator definition';end if;
 execute d;
end $$;
create or replace function public.deactivate_incident_join_code(p_join_code_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.incident_join_codes c where c.id=p_join_code_id and public.firemap_can_manage_incident(c.incident_id)) then raise exception 'Brak dostępu do tego kodu';end if;
 update public.incident_join_codes set active=false where id=p_join_code_id;return found;
end $$;
create or replace function public.expire_external_force_sessions() returns integer language plpgsql security definer set search_path='' as $$
declare n integer;begin
 if auth.uid() is null then raise exception 'Zaloguj się';end if;
 update public.incident_join_codes set active=false where active and expires_at<=now() and public.firemap_can_manage_incident(incident_id);
 with expired as(update public.external_force_sessions s set active=false where s.active and public.firemap_can_manage_incident(s.incident_id) and (s.expires_at<=now() or not exists(select 1 from public.incidents i where i.id=s.incident_id and i.active)) returning s.vehicle_id)
 update public.vehicles v set status='BASE',updated_at=now() where v.id in(select vehicle_id from expired);
 get diagnostics n=row_count;return n;
end $$;
revoke all on function public.deactivate_incident_join_code(uuid),public.expire_external_force_sessions() from public,anon;
grant execute on function public.deactivate_incident_join_code(uuid),public.expire_external_force_sessions() to authenticated,service_role;

-- Public login directory contains account labels and login aliases, never operational data.
create or replace function public.firemap_county_logins(p_county_id uuid) returns table(role text,unit_name text,login_email text)
language sql stable security definer set search_path='' as $$select a.role,a.unit_name,a.login_email from public.firemap_accounts a where a.county_id=p_county_id and a.enabled and a.role in ('SK','UNIT','JRG') and a.login_email is not null order by a.role,a.unit_name$$;
revoke all on function public.firemap_county_logins(uuid) from public;
grant execute on function public.firemap_county_logins(uuid) to anon,authenticated;

alter table public.external_force_sessions drop constraint external_force_sessions_force_group_check;
alter table public.external_force_sessions add constraint external_force_sessions_force_group_check check(force_group in ('LOCAL','WOO','COO','EXTERNAL'));
do $$declare d text;begin
 select pg_get_functiondef('public.external_force_join(text,text,text,text,text,text,text,text)'::regprocedure) into d;
 if position($old$p_force_group not in ('WOO','COO','EXTERNAL')$old$ in d)=0 then raise exception 'Unexpected join definition';end if;
 execute replace(d,$old$p_force_group not in ('WOO','COO','EXTERNAL')$old$,$new$p_force_group not in ('LOCAL','WOO','COO','EXTERNAL')$new$);
end $$;
