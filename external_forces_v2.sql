-- FIREMAP external forces v2
-- Bezpieczne dołączanie WOO/COO/grup specjalistycznych do konkretnego zdarzenia.
-- Wymaga uruchomienia w Supabase SQL Editor lub przez połączony plugin Supabase.

create extension if not exists pgcrypto;

alter table public.vehicles
  add column if not exists incident_id uuid references public.incidents(id) on delete set null,
  add column if not exists force_group text not null default 'LOCAL',
  add column if not exists specialist_group text,
  add column if not exists origin_voivodeship text,
  add column if not exists origin_county text,
  add column if not exists origin_unit text,
  add column if not exists external_session_id uuid;

alter table public.vehicles drop constraint if exists vehicles_force_group_check;
alter table public.vehicles add constraint vehicles_force_group_check
  check (force_group in ('LOCAL','WOO','COO','EXTERNAL'));

alter table public.vehicles drop constraint if exists vehicles_specialist_group_check;
alter table public.vehicles add constraint vehicles_specialist_group_check
  check (specialist_group is null or specialist_group in ('CHEM_ECO','WATER_DIVE','HEIGHT','TECH_SEARCH','USAR','DRONE','OTHER'));

-- Ujednolicenie typów pojazdów z aktualnym interfejsem FIREMAP Zastęp.
alter table public.vehicles drop constraint if exists vehicles_vehicle_type_check;
alter table public.vehicles add constraint vehicles_vehicle_type_check
  check (vehicle_type in ('GBA','GCBA','GBM','GLM','SD','SLRt','SLOp','SLKw','SLRR','MIKROBUS','PRZYCZEPA','QUAD','KDR','INNY'));

create index if not exists vehicles_incident_id_idx on public.vehicles(incident_id);

create table if not exists public.incident_join_codes (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  code text not null unique,
  active boolean not null default true,
  expires_at timestamptz not null,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index if not exists incident_join_codes_incident_idx on public.incident_join_codes(incident_id);
create index if not exists incident_join_codes_active_idx on public.incident_join_codes(active,expires_at);

create table if not exists public.external_force_sessions (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  join_code_id uuid not null references public.incident_join_codes(id) on delete cascade,
  token_hash bytea not null unique,
  vehicle_id uuid not null unique default gen_random_uuid(),
  force_group text not null check (force_group in ('WOO','COO','EXTERNAL')),
  specialist_group text check (specialist_group is null or specialist_group in ('CHEM_ECO','WATER_DIVE','HEIGHT','TECH_SEARCH','USAR','DRONE','OTHER')),
  origin_voivodeship text not null,
  origin_county text not null,
  origin_unit text not null,
  call_sign text not null,
  vehicle_type text not null,
  active boolean not null default true,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create index if not exists external_force_sessions_incident_idx on public.external_force_sessions(incident_id);
create index if not exists external_force_sessions_active_idx on public.external_force_sessions(active,expires_at);

alter table public.incident_join_codes enable row level security;
alter table public.external_force_sessions enable row level security;

drop policy if exists "SK read incident join codes" on public.incident_join_codes;
create policy "SK read incident join codes" on public.incident_join_codes
for select to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));

drop policy if exists "SK read external force sessions" on public.external_force_sessions;
create policy "SK read external force sessions" on public.external_force_sessions
for select to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));

revoke all on public.incident_join_codes from anon;
revoke all on public.external_force_sessions from anon;
grant select on public.incident_join_codes to authenticated;
grant select on public.external_force_sessions to authenticated;

create or replace function public.firemap_is_sk()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'); $$;

create or replace function public.create_incident_join_code(p_incident_id uuid, p_minutes integer default 120)
returns table(code text, expires_at timestamptz, join_code_id uuid)
language plpgsql security definer set search_path=public
as $$
declare v_code text;v_id uuid;v_exp timestamptz;i integer:=0;
begin
 if not public.firemap_is_sk() then raise exception 'Brak uprawnień SK'; end if;
 if not exists(select 1 from public.incidents x where x.id=p_incident_id and coalesce(x.active,true)=true) then raise exception 'Zdarzenie nie jest aktywne'; end if;
 p_minutes:=greatest(10,least(coalesce(p_minutes,120),1440));v_exp:=now()+make_interval(mins=>p_minutes);
 loop i:=i+1;v_code:=lpad((floor(random()*1000000))::int::text,6,'0');exit when not exists(select 1 from public.incident_join_codes c where c.code=v_code and c.active and c.expires_at>now());if i>20 then raise exception 'Nie udało się wygenerować unikalnego kodu';end if;end loop;
 insert into public.incident_join_codes(incident_id,code,expires_at,created_by) values(p_incident_id,v_code,v_exp,auth.uid()) returning id into v_id;
 return query select v_code,v_exp,v_id;
end;$$;

create or replace function public.deactivate_incident_join_code(p_join_code_id uuid)
returns boolean language plpgsql security definer set search_path=public
as $$ begin if not public.firemap_is_sk() then raise exception 'Brak uprawnień SK'; end if;update public.incident_join_codes set active=false where id=p_join_code_id;return found;end;$$;

create or replace function public.external_force_join(p_code text,p_force_group text,p_specialist_group text,p_voivodeship text,p_county text,p_unit text,p_call_sign text,p_vehicle_type text)
returns table(session_token text,session_id uuid,vehicle_id uuid,incident_id uuid,expires_at timestamptz,incident_kind text,incident_description text,incident_lat double precision,incident_lng double precision)
language plpgsql security definer set search_path=public
as $$
declare c public.incident_join_codes%rowtype;s_token text;s_id uuid;v_id uuid;s_exp timestamptz;inc public.incidents%rowtype;
begin
 p_code:=regexp_replace(coalesce(p_code,''),'\s','','g');
 if p_force_group not in ('WOO','COO','EXTERNAL') then raise exception 'Nieprawidłowa grupa sił';end if;
 if p_specialist_group is not null and p_specialist_group<>'' and p_specialist_group not in ('CHEM_ECO','WATER_DIVE','HEIGHT','TECH_SEARCH','USAR','DRONE','OTHER') then raise exception 'Nieprawidłowa grupa specjalistyczna';end if;
 if p_vehicle_type not in ('GBA','GCBA','GBM','GLM','SD','SLRt','SLOp','SLKw','SLRR','MIKROBUS','PRZYCZEPA','QUAD','INNY') then raise exception 'Nieprawidłowy typ pojazdu';end if;
 if length(trim(coalesce(p_voivodeship,'')))<2 or length(trim(coalesce(p_county,'')))<2 or length(trim(coalesce(p_unit,'')))<2 or length(trim(coalesce(p_call_sign,'')))<1 then raise exception 'Uzupełnij dane zastępu';end if;
 select * into c from public.incident_join_codes where code=p_code and active=true and expires_at>now() order by created_at desc limit 1;
 if c.id is null then raise exception 'Kod jest nieprawidłowy lub wygasł';end if;
 select * into inc from public.incidents where id=c.incident_id and coalesce(active,true)=true;if inc.id is null then raise exception 'Zdarzenie zostało zakończone';end if;
 s_token:=encode(gen_random_bytes(24),'hex');s_exp:=greatest(c.expires_at,now()+interval '12 hours');
 insert into public.external_force_sessions(incident_id,join_code_id,token_hash,force_group,specialist_group,origin_voivodeship,origin_county,origin_unit,call_sign,vehicle_type,expires_at)
 values(c.incident_id,c.id,digest(s_token,'sha256'),p_force_group,nullif(p_specialist_group,''),trim(p_voivodeship),trim(p_county),trim(p_unit),trim(p_call_sign),trim(p_vehicle_type),s_exp)
 returning id,vehicle_id into s_id,v_id;
 return query select s_token,s_id,v_id,c.incident_id,s_exp,inc.kind::text,coalesce(inc.description,''),inc.lat::double precision,inc.lng::double precision;
end;$$;

create or replace function public.external_force_update(p_session_token text,p_lat double precision,p_lng double precision,p_status text,p_accuracy double precision default null,p_speed double precision default null,p_heading double precision default null)
returns boolean language plpgsql security definer set search_path=public
as $$
declare s public.external_force_sessions%rowtype;
begin
 if p_status not in ('DISPATCHED','ON_SCENE','RETURNING','BASE') then raise exception 'Nieprawidłowy status';end if;if p_lat<-90 or p_lat>90 or p_lng<-180 or p_lng>180 then raise exception 'Nieprawidłowa pozycja';end if;
 select * into s from public.external_force_sessions where token_hash=digest(coalesce(p_session_token,''),'sha256') and active=true and expires_at>now() limit 1;if s.id is null then raise exception 'Sesja wygasła';end if;
 if not exists(select 1 from public.incidents i where i.id=s.incident_id and coalesce(i.active,true)=true) then update public.external_force_sessions set active=false where id=s.id;update public.vehicles set status='BASE',updated_at=now() where id=s.vehicle_id;raise exception 'Zdarzenie zostało zakończone';end if;
 update public.external_force_sessions set last_seen_at=now() where id=s.id;
 insert into public.vehicles(id,unit_name,call_sign,vehicle_type,status,lat,lng,accuracy,speed,heading,updated_at,incident_id,force_group,specialist_group,origin_voivodeship,origin_county,origin_unit,external_session_id)
 values(s.vehicle_id,s.origin_unit,s.call_sign,s.vehicle_type,p_status,p_lat,p_lng,case when p_accuracy is null then null else round(p_accuracy)::integer end,p_speed,p_heading,now(),s.incident_id,s.force_group,s.specialist_group,s.origin_voivodeship,s.origin_county,s.origin_unit,s.id)
 on conflict(id) do update set unit_name=excluded.unit_name,call_sign=excluded.call_sign,vehicle_type=excluded.vehicle_type,status=excluded.status,lat=excluded.lat,lng=excluded.lng,accuracy=excluded.accuracy,speed=excluded.speed,heading=excluded.heading,updated_at=excluded.updated_at,incident_id=excluded.incident_id,force_group=excluded.force_group,specialist_group=excluded.specialist_group,origin_voivodeship=excluded.origin_voivodeship,origin_county=excluded.origin_county,origin_unit=excluded.origin_unit,external_session_id=excluded.external_session_id;
 return true;
end;$$;

create or replace function public.external_force_leave(p_session_token text)
returns boolean language plpgsql security definer set search_path=public
as $$ declare s public.external_force_sessions%rowtype;begin select * into s from public.external_force_sessions where token_hash=digest(coalesce(p_session_token,''),'sha256') and active=true limit 1;if s.id is null then return false;end if;update public.external_force_sessions set active=false,last_seen_at=now() where id=s.id;update public.vehicles set status='BASE',updated_at=now() where id=s.vehicle_id;return true;end;$$;

create or replace function public.expire_external_force_sessions()
returns integer language plpgsql security definer set search_path=public
as $$ declare n integer;begin if not public.firemap_is_sk() then raise exception 'Brak uprawnień SK';end if;update public.incident_join_codes set active=false where active and expires_at<=now();with expired as (update public.external_force_sessions s set active=false where s.active and (s.expires_at<=now() or not exists(select 1 from public.incidents i where i.id=s.incident_id and coalesce(i.active,true)=true)) returning s.vehicle_id) update public.vehicles v set status='BASE',updated_at=now() where v.id in(select vehicle_id from expired);get diagnostics n=row_count;return n;end;$$;

create or replace function public.firemap_close_external_sessions_on_incident()
returns trigger language plpgsql security definer set search_path=public
as $$ begin if old.active is distinct from new.active and new.active=false then update public.incident_join_codes set active=false where incident_id=new.id;update public.external_force_sessions set active=false where incident_id=new.id and active=true;update public.vehicles set status='BASE',updated_at=now() where external_session_id in(select id from public.external_force_sessions where incident_id=new.id);end if;return new;end;$$;

drop trigger if exists firemap_close_external_sessions_on_incident on public.incidents;
create trigger firemap_close_external_sessions_on_incident after update of active on public.incidents for each row execute function public.firemap_close_external_sessions_on_incident();

grant execute on function public.create_incident_join_code(uuid,integer) to authenticated;
grant execute on function public.deactivate_incident_join_code(uuid) to authenticated;
grant execute on function public.expire_external_force_sessions() to authenticated;
grant execute on function public.external_force_join(text,text,text,text,text,text,text,text) to anon,authenticated;
grant execute on function public.external_force_update(text,double precision,double precision,text,double precision,double precision,double precision) to anon,authenticated;
grant execute on function public.external_force_leave(text) to anon,authenticated;
