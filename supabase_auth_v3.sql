-- FIREMAP v3 — AUTORYZACJA JEDNOSTEK
-- Uruchom ten plik w Supabase SQL Editor PO utworzeniu użytkowników w Authentication.
-- Hasła pozostają wyłącznie w Supabase Auth. Nigdy nie wpisuj haseł do tego pliku ani repozytorium.

create table if not exists public.firemap_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'UNIT' check (role in ('UNIT','JRG','SK')),
  unit_name text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.firemap_accounts enable row level security;
drop policy if exists "account read own" on public.firemap_accounts;
create policy "account read own" on public.firemap_accounts
for select to authenticated
using (user_id = auth.uid());

-- Automatycznie tworzy profil na podstawie e-maila użytkownika Auth.
-- Nazwę jednostki/rolę uzupełniamy niżej lub ręcznie w tabeli.
insert into public.firemap_accounts(user_id,role,unit_name,enabled)
select id,
  case when email='sk@firemap.local' then 'SK' when email='jrg-radomsko@firemap.local' then 'JRG' else 'UNIT' end,
  case when email='sk@firemap.local' then 'KP PSP Radomsko' when email='jrg-radomsko@firemap.local' then 'JRG Radomsko' else coalesce(raw_user_meta_data->>'unit_name',split_part(email,'@',1)) end,
  true
from auth.users
on conflict(user_id) do nothing;

-- WAŻNE: stare publiczne odczyty pozycji i zdarzeń usuwamy.
-- Mapa operacyjna ma działać wyłącznie po zalogowaniu.
drop policy if exists "public read vehicles" on public.vehicles;
drop policy if exists "anon read vehicles" on public.vehicles;
drop policy if exists "public read incidents" on public.incidents;

-- Zalogowane, aktywne konta FIREMAP mogą odczytać aktywne SIS.
drop policy if exists "verified read vehicles" on public.vehicles;
create policy "verified read vehicles" on public.vehicles
for select to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled));

drop policy if exists "verified read incidents" on public.incidents;
create policy "verified read incidents" on public.incidents
for select to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled));

-- SK: obsługa zdarzeń na podstawie ROLI, nie jawnego hasła/emaila w aplikacji.
drop policy if exists "SK create incidents" on public.incidents;
drop policy if exists "SK update incidents" on public.incidents;
drop policy if exists "SK delete incidents" on public.incidents;
create policy "SK create incidents" on public.incidents for insert to authenticated
with check (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));
create policy "SK update incidents" on public.incidents for update to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'))
with check (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));
create policy "SK delete incidents" on public.incidents for delete to authenticated
using (exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK'));

-- Konta specjalne — jeśli istnieją już w Authentication, ustaw role/nazwy.
update public.firemap_accounts a set role='SK',unit_name='KP PSP Radomsko'
from auth.users u where a.user_id=u.id and u.email='sk@firemap.local';
update public.firemap_accounts a set role='JRG',unit_name='JRG Radomsko'
from auth.users u where a.user_id=u.id and u.email='jrg-radomsko@firemap.local';
