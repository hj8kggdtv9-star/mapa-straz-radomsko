set local lock_timeout='3s';
set local statement_timeout='30s';

alter table public.incidents add column operation_area jsonb;
alter table public.incidents add column rapid_hq boolean not null default false;
create unique index one_rapid_hq_operation on public.incidents(sztab_id) where rapid_hq and active;
alter table public.incident_drawings add column guest_session_id uuid references public.external_force_sessions(id) on delete cascade;
alter table public.incident_drawings alter column created_by drop not null;
alter table public.incident_drawings add constraint drawing_author_kind check ((created_by is not null and guest_session_id is null) or (created_by is null and guest_session_id is not null));
create index drawings_guest_session_idx on public.incident_drawings(guest_session_id);

create or replace function public.firemap_sztab_logins() returns table(unit_name text,login_email text)
language sql stable security definer set search_path='' as $$
 select a.unit_name,a.login_email from public.firemap_accounts a where a.role='SZTAB' and a.enabled and a.login_email is not null order by a.unit_name;
$$;
revoke all on function public.firemap_sztab_logins() from public;
grant execute on function public.firemap_sztab_logins() to anon,authenticated;

create or replace function public.create_incident_join_code(p_incident_id uuid,p_minutes integer default 10080)
returns table(code text,expires_at timestamptz,join_code_id uuid)
language plpgsql security definer set search_path='' as $$
declare v_code text;v_id uuid;v_exp timestamptz;attempt integer:=0;
begin
 if not public.firemap_can_manage_incident(p_incident_id) then raise exception 'Brak dostępu do tego zdarzenia';end if;
 perform 1 from public.incidents i where i.id=p_incident_id and i.active for share;
 if not found then raise exception 'Zdarzenie nie jest aktywne';end if;
 if p_minutes is null or p_minutes<10 or p_minutes>43200 then raise exception 'Dostęp może trwać od 10 minut do 30 dni';end if;
 v_exp:=now()+make_interval(mins=>p_minutes);
 perform pg_advisory_xact_lock(71420391);
 loop
  attempt:=attempt+1;
  v_code:=lpad(((('x'||encode(extensions.gen_random_bytes(4),'hex'))::bit(32)::bigint % 1000000))::text,6,'0');
  exit when not exists(select 1 from public.incident_join_codes c where c.code=v_code and c.active and c.expires_at>now());
  if attempt>50 then raise exception 'Nie udało się wygenerować kodu';end if;
 end loop;
 insert into public.incident_join_codes(incident_id,code,expires_at,created_by) values(p_incident_id,v_code,v_exp,auth.uid()) returning id into v_id;
 return query select v_code,v_exp,v_id;
end $$;
revoke all on function public.create_incident_join_code(uuid,integer) from public,anon;
grant execute on function public.create_incident_join_code(uuid,integer) to authenticated;

create or replace function public.start_hq_operation(p_name text,p_area jsonb,p_days integer)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.firemap_accounts%rowtype;i public.incidents%rowtype;c record;b jsonb;lat float8;lng float8;
begin
 select * into a from public.firemap_accounts where user_id=auth.uid() and enabled and role='SZTAB';
 if a.user_id is null then raise exception 'Zaloguj się na konto SZTABU';end if;
 if p_days is null or p_days not in (1,3,7,14,30) then raise exception 'Wybierz 24 h, 3, 7, 14 lub 30 dni';end if;
 if p_name is null or length(trim(p_name)) not between 3 and 200 then raise exception 'Podaj nazwę akcji';end if;
 b:=p_area->'bounds';
 if p_area is null or jsonb_typeof(p_area)<>'object' or coalesce(length(p_area->>'province'),0) not between 2 and 60 or coalesce(length(p_area->>'county'),0) not between 2 and 100 or jsonb_typeof(b)<>'array' or jsonb_array_length(b)<>2 or jsonb_typeof(b->0)<>'array' or jsonb_typeof(b->1)<>'array' or jsonb_array_length(b->0)<>2 or jsonb_array_length(b->1)<>2 then raise exception 'Wybierz obszar działania';end if;
 if not ((b->0->>0)::float8 between -85 and 85 and (b->1->>0)::float8 between -85 and 85 and (b->0->>1)::float8 between -180 and 180 and (b->1->>1)::float8 between -180 and 180 and (b->0->>0)::float8<(b->1->>0)::float8 and (b->0->>1)::float8<(b->1->>1)::float8) then raise exception 'Nieprawidłowy obszar';end if;
 lat:=((b->0->>0)::float8+(b->1->>0)::float8)/2;lng:=((b->0->>1)::float8+(b->1->>1)::float8)/2;
 perform pg_advisory_xact_lock(hashtextextended(a.user_id::text,712));
 select * into i from public.incidents where sztab_id=a.user_id and rapid_hq and active for update;
 if i.id is null then
  insert into public.incidents(kind,lat,lng,description,operation_area,rapid_hq) values('FIRE',lat,lng,trim(p_name),jsonb_build_object('province',p_area->>'province','county',p_area->>'county','bounds',b,'center',jsonb_build_array(lat,lng)),true) returning * into i;
 elsif i.description<>trim(p_name) or i.operation_area->'bounds'<>b then raise exception 'Sztab ma już aktywną akcję. Zakończ ją przed uruchomieniem kolejnej';
 end if;
 select * into c from public.create_incident_join_code(i.id,p_days*1440);
 return jsonb_build_object('incident_id',i.id,'name',i.description,'area',i.operation_area,'code',c.code,'expires_at',c.expires_at,'join_code_id',c.join_code_id);
end $$;
revoke all on function public.start_hq_operation(text,jsonb,integer) from public,anon;
grant execute on function public.start_hq_operation(text,jsonb,integer) to authenticated;

-- Internal token validation; only the narrowly scoped RPCs below may invoke it.
create schema if not exists firemap_private;
revoke all on schema firemap_private from public,anon,authenticated;
create or replace function firemap_private.guest_session(p_token text) returns public.external_force_sessions
language plpgsql security definer set search_path='' as $$
declare s public.external_force_sessions%rowtype;
begin
 if p_token is null or p_token !~ '^[0-9a-f]{48}$' then raise exception 'Sesja wygasła';end if;
 select * into s from public.external_force_sessions where token_hash=extensions.digest(p_token,'sha256') and active and expires_at>now();
 if s.id is null or not exists(select 1 from public.incidents where id=s.incident_id and active) then raise exception 'Sesja wygasła';end if;
 return s;
end $$;
revoke all on function firemap_private.guest_session(text) from public,anon,authenticated;

create or replace function public.external_force_peers(p_session_token text)
returns table(id uuid,call_sign text,unit_name text,vehicle_type text,status text,lat float8,lng float8,updated_at timestamptz,force_group text,specialist_group text)
language plpgsql stable security definer set search_path='' as $$
declare s public.external_force_sessions%rowtype;hq uuid;
begin
 s:=firemap_private.guest_session(p_session_token);
 select i.sztab_id into hq from public.incidents i where i.id=s.incident_id;
 return query select v.id,v.call_sign,v.unit_name,v.vehicle_type,v.status,v.lat,v.lng,v.updated_at,v.force_group,v.specialist_group
 from public.vehicles v join public.incidents i on i.id=v.incident_id and i.active
 where (i.id=s.incident_id or (hq is not null and i.sztab_id=hq)) and v.id<>s.vehicle_id and v.status<>'BASE'
 and v.lat between -90 and 90 and v.lng between -180 and 180
 and (v.external_session_id is null or exists(select 1 from public.external_force_sessions p where p.id=v.external_session_id and p.vehicle_id=v.id and p.incident_id=i.id and p.active and p.expires_at>now())) order by v.id;
end $$;
revoke all on function public.external_force_peers(text) from public;
grant execute on function public.external_force_peers(text) to anon,authenticated;

create or replace function public.external_tactical_read(p_session_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.external_force_sessions%rowtype;i public.incidents%rowtype;rows jsonb;
begin
 s:=firemap_private.guest_session(p_session_token);select * into i from public.incidents where id=s.incident_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'incident_id',d.incident_id,'category',d.category,'geometry_type',d.geometry_type,'geometry',d.geometry,'style',d.style,'label',d.label,'created_by',coalesce(d.created_by,d.guest_session_id),'created_at',d.created_at,'updated_at',d.updated_at) order by d.created_at),'[]') into rows
 from public.incident_drawings d join public.incidents x on x.id=d.incident_id and x.active
 where x.id=i.id or (i.sztab_id is not null and x.sztab_id=i.sztab_id);
 return jsonb_build_object('incident',jsonb_build_object('id',i.id,'kind',i.kind,'description',i.description,'active',i.active,'operation_area',i.operation_area),'drawings',rows,'expires_at',s.expires_at);
end $$;
revoke all on function public.external_tactical_read(text) from public;
grant execute on function public.external_tactical_read(text) to anon,authenticated;

create or replace function public.external_tactical_write(p_session_token text,p_rows jsonb default '[]',p_delete_ids uuid[] default '{}')
returns boolean language plpgsql security definer set search_path='' as $$
declare s public.external_force_sessions%rowtype;r jsonb;g jsonb;pt jsonb;st jsonb;did uuid;n integer;k text;
begin
 s:=firemap_private.guest_session(p_session_token);
 -- Same lock order as incident closure: incident, then session.
 perform 1 from public.incidents where id=s.incident_id and active for share;
 if not found then raise exception 'Sesja wygasła';end if;
 perform 1 from public.external_force_sessions where id=s.id and active and expires_at>now() for update;
 if not found then raise exception 'Sesja wygasła';end if;
 if p_rows is null or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>200 or octet_length(p_rows::text)>1000000 or coalesce(array_length(p_delete_ids,1),0)>200 then raise exception 'Zbyt duży pakiet taktyki';end if;
 if exists(select 1 from public.incident_drawings d where d.id=any(p_delete_ids) and (d.guest_session_id is distinct from s.id or d.incident_id<>s.incident_id)) then raise exception 'Możesz usuwać tylko własną taktykę';end if;
 for r in select value from jsonb_array_elements(p_rows) loop
  did:=(r->>'id')::uuid;g:=r->'geometry';st:=coalesce(r->'style','{}');
  if did is null or r->>'category' is null or r->>'category' not in ('SECTOR','WATER','DANGER','FIRE_SPREAD','FREEHAND') or r->>'geometry_type' is null or r->>'geometry_type' not in ('CIRCLE','POLYGON','POLYLINE','FREEHAND') or coalesce(length(r->>'label'),0)>200 or jsonb_typeof(g) is distinct from 'object' or jsonb_typeof(st) is distinct from 'object' then raise exception 'Nieprawidłowy element taktyki';end if;
  if exists(select 1 from public.incident_drawings d where d.id=did and (d.guest_session_id is distinct from s.id or d.incident_id<>s.incident_id)) then raise exception 'Możesz edytować tylko własną taktykę';end if;
  if r->>'geometry_type'='CIRCLE' then
   if (jsonb_typeof(g->'center')='array' and jsonb_array_length(g->'center')=2 and jsonb_typeof(g->'radius')='number' and (g->>'radius')::float8 between 0 and 1000000) is not true then raise exception 'Nieprawidłowy okrąg';end if;
   g:=jsonb_build_object('center',g->'center','radius',g->'radius');
  else
   if jsonb_typeof(g->'points') is distinct from 'array' then raise exception 'Brak punktów';end if;
   n:=jsonb_array_length(g->'points');if n<(case when r->>'geometry_type'='POLYGON' then 3 else 2 end) or n>2000 then raise exception 'Nieprawidłowa liczba punktów';end if;
   g:=jsonb_build_object('points',g->'points');
  end if;
  for pt in select value from jsonb_array_elements(case when r->>'geometry_type'='CIRCLE' then jsonb_build_array(g->'center') else g->'points' end) loop
   if jsonb_typeof(pt) is distinct from 'array' or jsonb_array_length(pt)<>2 or jsonb_typeof(pt->0) is distinct from 'number' or jsonb_typeof(pt->1) is distinct from 'number' or not ((pt->>0)::float8 between -90 and 90 and (pt->>1)::float8 between -180 and 180) then raise exception 'Nieprawidłowe współrzędne';end if;
  end loop;
  -- All strings used in style attributes are constrained; labels are escaped by clients.
  for k in select jsonb_object_keys(st) loop
   if k in ('color','fillColor','pointColor') and (st->>k) !~ '^#[0-9a-fA-F]{3,8}$' then raise exception 'Nieprawidłowy kolor';end if;
   if k in ('weight','radius','opacity','fillOpacity') and (jsonb_typeof(st->k)<>'number' or (st->>k)::float8 not between 0 and 1000000) then raise exception 'Nieprawidłowy styl';end if;
   if k in ('pointName','pointDescription','sectorName','sectorDescription') and length(st->>k)>500 then raise exception 'Zbyt długi opis';end if;
  end loop;
  select coalesce(jsonb_object_agg(key,value),'{}') into st from jsonb_each(st) where key in ('color','fillColor','pointColor','weight','opacity','fillOpacity','point','pointName','pointDescription','sectorName','sectorDescription');
  insert into public.incident_drawings(id,incident_id,category,geometry_type,geometry,style,label,created_by,guest_session_id)
  values(did,s.incident_id,r->>'category',r->>'geometry_type',g,st,r->>'label',null,s.id)
  on conflict(id) do update set geometry=excluded.geometry,style=excluded.style,label=excluded.label,category=excluded.category,geometry_type=excluded.geometry_type,updated_at=now()
  where public.incident_drawings.guest_session_id=s.id and public.incident_drawings.incident_id=s.incident_id;
  get diagnostics n=row_count;if n<>1 then raise exception 'Brak dostępu do elementu';end if;
 end loop;
 delete from public.incident_drawings where id=any(p_delete_ids) and guest_session_id=s.id and incident_id=s.incident_id;
 if (select count(*) from public.incident_drawings where guest_session_id=s.id)>200 then raise exception 'Limit 200 elementów na zastęp';end if;
 return true;
end $$;
revoke all on function public.external_tactical_write(text,jsonb,uuid[]) from public;
grant execute on function public.external_tactical_write(text,jsonb,uuid[]) to anon,authenticated;
