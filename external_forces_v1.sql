-- FIREMAP — WOO/COO v1
-- Tymczasowe dołączanie sił zewnętrznych kodem/QR do konkretnego zdarzenia.
-- Ten skrypt jest idempotentny. Uruchom go w Supabase SQL Editor / migracji.

create extension if not exists pgcrypto;

alter table public.vehicles add column if not exists force_group text;
alter table public.vehicles add column if not exists origin_voivodeship text;
alter table public.vehicles add column if not exists origin_county text;
alter table public.vehicles add column if not exists origin_unit text;
alter table public.vehicles add column if not exists external_session_token uuid;

create index if not exists vehicles_force_group_idx on public.vehicles(force_group);
create index if not exists vehicles_external_session_idx on public.vehicles(external_session_token);

create table if not exists public.external_force_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[0-9]{6}$'),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  force_group text not null check (force_group in ('WOO','COO')),
  created_by uuid,
  active boolean not null default true,
  expires_at timestamptz not null default (now() + interval '12 hours'),
  created_at timestamptz not null default now()
);

create table if not exists public.external_force_sessions (
  token uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.external_force_invites(id) on delete cascade,
  incident_id uuid not null references public.incidents(id) on delete cascade,
  force_group text not null check (force_group in ('WOO','COO')),
  origin_voivodeship text not null,
  origin_county text not null,
  origin_unit text not null,
  call_sign text not null,
  vehicle_type text not null,
  vehicle_id uuid not null default gen_random_uuid(),
  active boolean not null default true,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create index if not exists external_force_invites_incident_idx on public.external_force_invites(incident_id,active,expires_at);
create index if not exists external_force_sessions_incident_idx on public.external_force_sessions(incident_id,active,expires_at);

alter table public.external_force_invites enable row level security;
alter table public.external_force_sessions enable row level security;

-- Tylko SK zarządza zaproszeniami bezpośrednio.
drop policy if exists "SK read external invites" on public.external_force_invites;
create policy "SK read external invites" on public.external_force_invites
for select to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));

drop policy if exists "SK insert external invites" on public.external_force_invites;
create policy "SK insert external invites" on public.external_force_invites
for insert to authenticated
with check (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));

drop policy if exists "SK update external invites" on public.external_force_invites;
create policy "SK update external invites" on public.external_force_invites
for update to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'))
with check (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));

drop policy if exists "SK delete external invites" on public.external_force_invites;
create policy "SK delete external invites" on public.external_force_invites
for delete to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));

-- Sesje zewnętrzne nie mają bezpośrednich polityk SELECT/INSERT/UPDATE.
-- Dostęp odbywa się wyłącznie przez poniższe funkcje SECURITY DEFINER z bearer-tokenem sesji.

drop function if exists public.external_force_create_invite(uuid,text,integer);
create function public.external_force_create_invite(p_incident_id uuid,p_force_group text,p_hours integer default 12)
returns table(code text,expires_at timestamptz)
language plpgsql security definer set search_path=public
as $$
declare
  v_code text;
  v_exp timestamptz;
  v_try integer:=0;
begin
  if not exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK') then
    raise exception 'Brak uprawnień SK';
  end if;
  if upper(p_force_group) not in ('WOO','COO') then raise exception 'Nieprawidłowa grupa'; end if;
  if not exists(select 1 from public.incidents i where i.id=p_incident_id and coalesce(i.active,true)=true) then
    raise exception 'Zdarzenie nie jest aktywne';
  end if;
  v_exp:=now()+make_interval(hours=>greatest(1,least(coalesce(p_hours,12),48)));
  loop
    v_try:=v_try+1;
    v_code:=lpad((floor(random()*1000000))::int::text,6,'0');
    begin
      insert into public.external_force_invites(code,incident_id,force_group,created_by,expires_at)
      values(v_code,p_incident_id,upper(p_force_group),auth.uid(),v_exp);
      exit;
    exception when unique_violation then
      if v_try>20 then raise; end if;
    end;
  end loop;
  return query select v_code,v_exp;
end $$;

drop function if exists public.external_force_revoke_invite(uuid);
create function public.external_force_revoke_invite(p_invite_id uuid)
returns boolean language plpgsql security definer set search_path=public
as $$
begin
  if not exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK') then raise exception 'Brak uprawnień SK'; end if;
  update public.external_force_invites set active=false where id=p_invite_id;
  update public.external_force_sessions set active=false where invite_id=p_invite_id;
  update public.vehicles set status='BASE',updated_at=now() where external_session_token in (select token from public.external_force_sessions where invite_id=p_invite_id);
  return true;
end $$;

drop function if exists public.external_force_join(text,text,text,text,text,text,text);
create function public.external_force_join(
  p_code text,
  p_force_group text,
  p_voivodeship text,
  p_county text,
  p_unit text,
  p_call_sign text,
  p_vehicle_type text
) returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_inv public.external_force_invites%rowtype;
  v_token uuid:=gen_random_uuid();
  v_vehicle uuid:=gen_random_uuid();
  v_inc public.incidents%rowtype;
begin
  select * into v_inv from public.external_force_invites
  where code=trim(p_code) and active=true and expires_at>now()
  order by created_at desc limit 1;
  if v_inv.id is null then raise exception 'Kod jest nieprawidłowy lub wygasł'; end if;
  if upper(trim(p_force_group))<>v_inv.force_group then raise exception 'Kod nie pasuje do wybranej grupy'; end if;
  if nullif(trim(p_voivodeship),'') is null or nullif(trim(p_county),'') is null or nullif(trim(p_unit),'') is null or nullif(trim(p_call_sign),'') is null then
    raise exception 'Uzupełnij województwo, powiat, jednostkę i kryptonim';
  end if;
  select * into v_inc from public.incidents where id=v_inv.incident_id and coalesce(active,true)=true;
  if v_inc.id is null then raise exception 'Zdarzenie zostało zakończone'; end if;

  insert into public.external_force_sessions(token,invite_id,incident_id,force_group,origin_voivodeship,origin_county,origin_unit,call_sign,vehicle_type,vehicle_id,expires_at)
  values(v_token,v_inv.id,v_inv.incident_id,v_inv.force_group,trim(p_voivodeship),trim(p_county),trim(p_unit),trim(p_call_sign),trim(p_vehicle_type),v_vehicle,v_inv.expires_at);

  return jsonb_build_object(
    'token',v_token,'vehicle_id',v_vehicle,'expires_at',v_inv.expires_at,
    'incident',jsonb_build_object('id',v_inc.id,'kind',v_inc.kind,'lat',v_inc.lat,'lng',v_inc.lng,'description',v_inc.description),
    'force_group',v_inv.force_group
  );
end $$;

drop function if exists public.external_force_publish(uuid,text,double precision,double precision,integer,double precision,double precision);
create function public.external_force_publish(
  p_token uuid,p_status text,p_lat double precision,p_lng double precision,p_accuracy integer default null,p_speed double precision default null,p_heading double precision default null
) returns boolean
language plpgsql security definer set search_path=public
as $$
declare s public.external_force_sessions%rowtype;
begin
  select * into s from public.external_force_sessions where token=p_token and active=true and expires_at>now();
  if s.token is null then raise exception 'Sesja wygasła'; end if;
  if not exists(select 1 from public.incidents i where i.id=s.incident_id and coalesce(i.active,true)=true) then raise exception 'Zdarzenie zakończone'; end if;
  if upper(p_status) not in ('BASE','DISPATCHED','ON_SCENE','RETURNING') then raise exception 'Nieprawidłowy status'; end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'Nieprawidłowa pozycja'; end if;

  insert into public.vehicles(id,unit_name,call_sign,vehicle_type,status,lat,lng,accuracy,speed,heading,updated_at,incident_id,force_group,origin_voivodeship,origin_county,origin_unit,external_session_token)
  values(s.vehicle_id,s.origin_unit,s.call_sign,s.vehicle_type,upper(p_status),p_lat,p_lng,p_accuracy,p_speed,p_heading,now(),s.incident_id,s.force_group,s.origin_voivodeship,s.origin_county,s.origin_unit,s.token)
  on conflict(id) do update set
    unit_name=excluded.unit_name,call_sign=excluded.call_sign,vehicle_type=excluded.vehicle_type,status=excluded.status,
    lat=excluded.lat,lng=excluded.lng,accuracy=excluded.accuracy,speed=excluded.speed,heading=excluded.heading,updated_at=now(),incident_id=excluded.incident_id,
    force_group=excluded.force_group,origin_voivodeship=excluded.origin_voivodeship,origin_county=excluded.origin_county,origin_unit=excluded.origin_unit,external_session_token=excluded.external_session_token;
  update public.external_force_sessions set last_seen_at=now() where token=s.token;
  return true;
end $$;

drop function if exists public.external_force_snapshot(uuid);
create function public.external_force_snapshot(p_token uuid)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare s public.external_force_sessions%rowtype; r jsonb;
begin
  select * into s from public.external_force_sessions where token=p_token and active=true and expires_at>now();
  if s.token is null then raise exception 'Sesja wygasła'; end if;
  select jsonb_build_object(
    'incident',(select jsonb_build_object('id',i.id,'kind',i.kind,'lat',i.lat,'lng',i.lng,'description',i.description,'active',i.active) from public.incidents i where i.id=s.incident_id),
    'vehicles',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'unit_name',v.unit_name,'call_sign',v.call_sign,'vehicle_type',v.vehicle_type,'status',v.status,'lat',v.lat,'lng',v.lng,'updated_at',v.updated_at,'force_group',v.force_group,'origin_voivodeship',v.origin_voivodeship,'origin_county',v.origin_county,'origin_unit',v.origin_unit)) from public.vehicles v where v.status<>'BASE' and v.updated_at>now()-interval '8 hours' and (v.incident_id=s.incident_id or v.incident_id is null)),'[]'::jsonb)
  ) into r;
  return r;
end $$;

grant execute on function public.external_force_join(text,text,text,text,text,text,text) to anon,authenticated;
grant execute on function public.external_force_publish(uuid,text,double precision,double precision,integer,double precision,double precision) to anon,authenticated;
grant execute on function public.external_force_snapshot(uuid) to anon,authenticated;
grant execute on function public.external_force_create_invite(uuid,text,integer) to authenticated;
grant execute on function public.external_force_revoke_invite(uuid) to authenticated;
