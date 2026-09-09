-- Separate operational headquarters accounts. Existing SK/OSP roles retain their policies.
alter table public.firemap_accounts drop constraint firemap_accounts_role_check;
alter table public.firemap_accounts add constraint firemap_accounts_role_check check(role in ('UNIT','JRG','SK','SZTAB'));

create or replace function public.firemap_sztab_id() returns uuid
language sql stable security invoker set search_path='' as $$
 select user_id from public.firemap_accounts where user_id=auth.uid() and enabled and role='SZTAB'
$$;
revoke all on function public.firemap_sztab_id() from public;
grant execute on function public.firemap_sztab_id() to authenticated;
alter table public.incidents add column sztab_id uuid references public.firemap_accounts(user_id) default public.firemap_sztab_id();
create index incidents_sztab_id_idx on public.incidents(sztab_id);

create policy "sztab incident scope" on public.incidents as restrictive for all to authenticated
using ((select public.firemap_sztab_id()) is null or sztab_id=(select auth.uid()))
with check ((select public.firemap_sztab_id()) is null or sztab_id=(select auth.uid()));
create policy "sztab manage own incidents" on public.incidents for all to authenticated
using (sztab_id=(select public.firemap_sztab_id()))
with check (sztab_id=(select public.firemap_sztab_id()));
create policy "sztab vehicle scope" on public.vehicles as restrictive for all to authenticated
using ((select public.firemap_sztab_id()) is null or exists(select 1 from public.incidents i where i.id=vehicles.incident_id and i.sztab_id=(select auth.uid())))
with check ((select public.firemap_sztab_id()) is null or exists(select 1 from public.incidents i where i.id=vehicles.incident_id and i.sztab_id=(select auth.uid())));
create policy "sztab drawing scope" on public.incident_drawings as restrictive for all to authenticated
using ((select public.firemap_sztab_id()) is null or exists(select 1 from public.incidents i where i.id=incident_drawings.incident_id and i.sztab_id=(select auth.uid())))
with check ((select public.firemap_sztab_id()) is null or exists(select 1 from public.incidents i where i.id=incident_drawings.incident_id and i.sztab_id=(select auth.uid())));
create policy "sztab read own codes" on public.incident_join_codes for select to authenticated
using (exists(select 1 from public.incidents i where i.id=incident_join_codes.incident_id and i.sztab_id=(select public.firemap_sztab_id())));
create policy "sztab read own sessions" on public.external_force_sessions for select to authenticated
using (exists(select 1 from public.incidents i where i.id=external_force_sessions.incident_id and i.sztab_id=(select public.firemap_sztab_id())));

create or replace function public.create_incident_join_code(p_incident_id uuid,p_minutes integer default 10080)
returns table(code text,expires_at timestamptz,join_code_id uuid)
language plpgsql security definer set search_path='' as $$
declare v_code text;v_id uuid;v_exp timestamptz;i integer:=0;
begin
 if auth.uid() is null or not (public.firemap_is_sk() or exists(select 1 from public.incidents x join public.firemap_accounts a on a.user_id=x.sztab_id where x.id=p_incident_id and a.user_id=auth.uid() and a.enabled and a.role='SZTAB')) then raise exception 'Brak dostępu do tego zdarzenia';end if;
 if not exists(select 1 from public.incidents x where x.id=p_incident_id and x.active) then raise exception 'Zdarzenie nie jest aktywne';end if;
 p_minutes:=greatest(10,least(coalesce(p_minutes,10080),10080));v_exp:=now()+make_interval(mins=>p_minutes);
 -- Serialize allocation in the six-digit namespace, including concurrent requests.
 perform pg_advisory_xact_lock(71420391);
 loop
  i:=i+1;
  v_code:=lpad(((('x'||encode(extensions.gen_random_bytes(4),'hex'))::bit(32)::bigint % 1000000))::text,6,'0');
  exit when not exists(select 1 from public.incident_join_codes c where c.code=v_code and c.active and c.expires_at>now());
  if i>50 then raise exception 'Nie udało się wygenerować kodu';end if;
 end loop;
 insert into public.incident_join_codes(incident_id,code,expires_at,created_by) values(p_incident_id,v_code,v_exp,auth.uid()) returning id into v_id;
 return query select v_code,v_exp,v_id;
end $$;
revoke all on function public.create_incident_join_code(uuid,integer) from public,anon;
grant execute on function public.create_incident_join_code(uuid,integer) to authenticated;

create or replace function public.deactivate_incident_join_code(p_join_code_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.firemap_is_sk() or exists(select 1 from public.incident_join_codes c join public.incidents i on i.id=c.incident_id join public.firemap_accounts a on a.user_id=i.sztab_id where c.id=p_join_code_id and a.user_id=auth.uid() and a.role='SZTAB' and a.enabled)) then raise exception 'Brak dostępu do tego kodu';end if;
 update public.incident_join_codes set active=false where id=p_join_code_id;
 return found;
end $$;
revoke all on function public.deactivate_incident_join_code(uuid) from public,anon;
grant execute on function public.deactivate_incident_join_code(uuid) to authenticated;

-- Extend new sessions to their join code expiry; existing sessions remain unchanged.
do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.external_force_join(text,text,text,text,text,text,text,text)'::regprocedure) into definition;
 if position('least(c.expires_at,now()+interval ''12 hours'')' in definition)=0 then raise exception 'Unexpected external_force_join version';end if;
 execute replace(definition,'least(c.expires_at,now()+interval ''12 hours'')','c.expires_at');
end $migration$;
