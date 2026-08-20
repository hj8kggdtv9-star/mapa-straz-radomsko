-- FIREMAP v2 — uruchom w Supabase SQL Editor
alter table public.vehicles add column if not exists status text not null default 'BASE';
alter table public.vehicles add column if not exists speed double precision;
alter table public.vehicles add column if not exists heading double precision;
alter table public.vehicles drop constraint if exists vehicles_status_check;
alter table public.vehicles add constraint vehicles_status_check check (status in ('BASE','DISPATCHED','ON_SCENE','RETURNING'));
create table if not exists public.incidents (id uuid primary key default gen_random_uuid(),kind text not null check (kind in ('FIRE','MZ')),lat double precision not null,lng double precision not null,description text,active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by text default (auth.jwt() ->> 'email'));
alter table public.incidents enable row level security;
drop policy if exists "public read incidents" on public.incidents;
drop policy if exists "SK create incidents" on public.incidents;
drop policy if exists "SK update incidents" on public.incidents;
drop policy if exists "SK delete incidents" on public.incidents;
create policy "public read incidents" on public.incidents for select to anon, authenticated using (true);
create policy "SK create incidents" on public.incidents for insert to authenticated with check ((auth.jwt() ->> 'email') = 'sk@firemap.local');
create policy "SK update incidents" on public.incidents for update to authenticated using ((auth.jwt() ->> 'email') = 'sk@firemap.local') with check ((auth.jwt() ->> 'email') = 'sk@firemap.local');
create policy "SK delete incidents" on public.incidents for delete to authenticated using ((auth.jwt() ->> 'email') = 'sk@firemap.local');
do $$ begin if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='incidents') then alter publication supabase_realtime add table public.incidents; end if; end $$;