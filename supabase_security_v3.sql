-- FIREMAP security v3
-- Uruchom w Supabase SQL Editor dopiero gdy będziemy gotowi aktywować logowanie pojazdów.
-- Cel: tylko autoryzowane konta VEHICLE i SK widzą dane operacyjne.

create table if not exists public.firemap_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('VEHICLE','SK')),
  unit_name text,
  call_sign text,
  vehicle_type text,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists firemap_accounts_call_sign_unique
on public.firemap_accounts(call_sign)
where call_sign is not null;

alter table public.firemap_accounts enable row level security;

-- Powiąż rekord pozycji z konkretnym kontem Auth.
alter table public.vehicles
add column if not exists auth_user_id uuid references auth.users(id) on delete set null;

create index if not exists vehicles_auth_user_id_idx
on public.vehicles(auth_user_id);

-- Usuń dotychczasowe polityki na warstwach operacyjnych.
do $$
declare p record;
begin
  for p in select policyname from pg_policies where schemaname='public' and tablename='vehicles' loop
    execute format('drop policy if exists %I on public.vehicles', p.policyname);
  end loop;
  for p in select policyname from pg_policies where schemaname='public' and tablename='incidents' loop
    execute format('drop policy if exists %I on public.incidents', p.policyname);
  end loop;
  for p in select policyname from pg_policies where schemaname='public' and tablename='firemap_accounts' loop
    execute format('drop policy if exists %I on public.firemap_accounts', p.policyname);
  end loop;
end $$;

alter table public.vehicles enable row level security;
alter table public.incidents enable row level security;

-- Użytkownik może odczytać tylko swój profil FIREMAP.
create policy "account read own"
on public.firemap_accounts
for select
to authenticated
using (user_id = auth.uid());

-- Autoryzowany VEHICLE lub SK może oglądać warstwę pojazdów.
create policy "authorized read vehicles"
on public.vehicles
for select
to authenticated
using (
  exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid()
      and a.enabled = true
      and a.role in ('VEHICLE','SK')
  )
);

-- Pojazd może utworzyć wyłącznie własny rekord i nie może podszyć się pod inny numer.
create policy "vehicle insert own"
on public.vehicles
for insert
to authenticated
with check (
  auth_user_id = auth.uid()
  and exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid()
      and a.enabled = true
      and a.role = 'VEHICLE'
      and a.call_sign = vehicles.call_sign
      and a.unit_name = vehicles.unit_name
      and a.vehicle_type = vehicles.vehicle_type
  )
);

-- Pojazd aktualizuje wyłącznie swój rekord.
create policy "vehicle update own"
on public.vehicles
for update
to authenticated
using (
  auth_user_id = auth.uid()
  and exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid()
      and a.enabled = true
      and a.role = 'VEHICLE'
  )
)
with check (
  auth_user_id = auth.uid()
  and exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid()
      and a.enabled = true
      and a.role = 'VEHICLE'
      and a.call_sign = vehicles.call_sign
      and a.unit_name = vehicles.unit_name
      and a.vehicle_type = vehicles.vehicle_type
  )
);

-- Autoryzowane konta widzą aktywne zdarzenia.
create policy "authorized read incidents"
on public.incidents
for select
to authenticated
using (
  exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid()
      and a.enabled = true
      and a.role in ('VEHICLE','SK')
  )
);

-- Tylko SK może tworzyć/zmieniać/usuwać zdarzenia.
create policy "SK insert incidents"
on public.incidents
for insert
to authenticated
with check (
  exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid() and a.enabled = true and a.role = 'SK'
  )
);

create policy "SK update incidents"
on public.incidents
for update
to authenticated
using (
  exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid() and a.enabled = true and a.role = 'SK'
  )
)
with check (
  exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid() and a.enabled = true and a.role = 'SK'
  )
);

create policy "SK delete incidents"
on public.incidents
for delete
to authenticated
using (
  exists (
    select 1 from public.firemap_accounts a
    where a.user_id = auth.uid() and a.enabled = true and a.role = 'SK'
  )
);

-- Podłącz istniejące konto dyżurnego do roli SK.
insert into public.firemap_accounts(user_id,role,unit_name,enabled)
select id,'SK','SK KP PSP Radomsko',true
from auth.users
where email='sk@firemap.local'
on conflict (user_id) do update
set role='SK',unit_name='SK KP PSP Radomsko',enabled=true;

-- PRZYKŁAD DODANIA POJAZDU PO UTWORZENIU UŻYTKOWNIKA W Authentication -> Users:
-- login techniczny: 511-25@firemap.local
--
-- insert into public.firemap_accounts(user_id,role,unit_name,call_sign,vehicle_type,enabled)
-- select id,'VEHICLE','JRG Radomsko','511-25','GBA',true
-- from auth.users
-- where email='511-25@firemap.local'
-- on conflict (user_id) do update
-- set role='VEHICLE',unit_name='JRG Radomsko',call_sign='511-25',vehicle_type='GBA',enabled=true;

-- Aby natychmiast zablokować konto bez usuwania go:
-- update public.firemap_accounts set enabled=false where call_sign='511-25';
