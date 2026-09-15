set local lock_timeout='3s';
set local statement_timeout='30s';
alter table public.firemap_accounts add column archived_at timestamptz;
alter table public.firemap_accounts add constraint archived_account_disabled check (archived_at is null or not enabled);
drop index public.firemap_one_sk_per_county;
create unique index firemap_one_sk_per_county on public.firemap_accounts(county_id) where role='SK' and archived_at is null;
-- A disabled identity must not retain write access through a previously issued JWT.
create function public.firemap_operational_account_active() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.firemap_accounts where user_id=auth.uid() and enabled and archived_at is null);
$$;
revoke all on function public.firemap_operational_account_active() from public,anon;
grant execute on function public.firemap_operational_account_active() to authenticated;
do $$declare t text;begin
 foreach t in array array['vehicles','incidents','incident_drawings','incident_join_codes','external_force_sessions'] loop
  execute format('create policy active_operational_account on public.%I as restrictive for all to authenticated using(public.firemap_operational_account_active()) with check(public.firemap_operational_account_active())',t);
 end loop;
end $$;
create function public.firemap_admin_account_change(p_actor uuid,p_target uuid,p_action text,p_name text default null,p_county uuid default null,p_confirmation text default null)
returns boolean language plpgsql security invoker set search_path='' as $$
declare a public.firemap_accounts%rowtype;
begin
 if not exists(select 1 from public.firemap_platform_admins where user_id=p_actor) or exists(select 1 from public.firemap_accounts where user_id=p_actor and (not enabled or archived_at is not null)) then raise exception 'Brak uprawnień administratora';end if;
 if p_target=p_actor or exists(select 1 from public.firemap_platform_admins where user_id=p_target) then raise exception 'Konto administratora jest chronione przed tą operacją';end if;
 select * into a from public.firemap_accounts where user_id=p_target for update;
 if a.user_id is null or a.archived_at is not null then raise exception 'Konto nie istnieje lub zostało usunięte z użytkowania';end if;
 if p_action='archive' then
  if p_confirmation is distinct from a.login_email then raise exception 'Wpisz dokładny login konta, aby potwierdzić usunięcie';end if;
  update public.firemap_accounts set enabled=false,archived_at=now() where user_id=p_target;
 elsif p_action in ('enable','disable') then
  update public.firemap_accounts set enabled=(p_action='enable') where user_id=p_target;
 elsif p_action='rename' then
  if p_name is null or length(trim(p_name)) not between 3 and 100 then raise exception 'Nazwa musi mieć 3–100 znaków';end if;
  update public.firemap_accounts set unit_name=trim(p_name) where user_id=p_target;
 elsif p_action='move' then
  if not exists(select 1 from public.firemap_counties where id=p_county) then raise exception 'Wybierz istniejący powiat';end if;
  if exists(select 1 from public.vehicles where account_id=p_target) or exists(select 1 from public.incidents where sztab_id=p_target) then raise exception 'Konto ma przypisane pojazdy lub historię sztabu. Utwórz nowe konto w docelowym powiecie';end if;
  update public.firemap_accounts set county_id=p_county where user_id=p_target;
 else raise exception 'Nieznana operacja';end if;
 return true;
end $$;
revoke all on function public.firemap_admin_account_change(uuid,uuid,text,text,uuid,text) from public,anon,authenticated;
grant execute on function public.firemap_admin_account_change(uuid,uuid,text,text,uuid,text) to service_role;
