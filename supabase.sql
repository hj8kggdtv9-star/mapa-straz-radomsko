create table if not exists public.vehicles (
  id uuid primary key,
  unit_name text not null check (char_length(unit_name) between 1 and 80),
  call_sign text not null check (char_length(call_sign) between 1 and 20),
  vehicle_type text not null check (vehicle_type in ('GBA','GCBA','SD','SLRt','SLOp','INNY')),
  lat double precision not null,
  lng double precision not null,
  accuracy integer,
  updated_at timestamptz not null default now()
);
alter table public.vehicles enable row level security;
drop policy if exists "public read vehicles" on public.vehicles;
drop policy if exists "public insert vehicles" on public.vehicles;
drop policy if exists "public update vehicles" on public.vehicles;
drop policy if exists "public delete vehicles" on public.vehicles;
create policy "public read vehicles" on public.vehicles for select to anon, authenticated using (true);
create policy "public insert vehicles" on public.vehicles for insert to anon, authenticated with check (lat between 50.70 and 51.40 and lng between 18.70 and 20.25);
create policy "public update vehicles" on public.vehicles for update to anon, authenticated using (true) with check (lat between 50.70 and 51.40 and lng between 18.70 and 20.25);
create policy "public delete vehicles" on public.vehicles for delete to anon, authenticated using (true);
alter publication supabase_realtime add table public.vehicles;
