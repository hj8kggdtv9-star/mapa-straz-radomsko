-- FIREMAP — wspólna warstwa taktyczna KDR
-- Uruchom CAŁY plik w Supabase -> SQL Editor -> Run.
-- Wymaga istniejących tabel: firemap_accounts oraz incidents.

create table if not exists public.incident_drawings (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  category text not null check (category in ('SECTOR','WATER','DANGER','FIRE_SPREAD','FREEHAND')),
  geometry_type text not null check (geometry_type in ('POLYLINE','POLYGON','CIRCLE','FREEHAND')),
  geometry jsonb not null,
  style jsonb not null default '{}'::jsonb,
  label text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists incident_drawings_incident_idx on public.incident_drawings(incident_id);
create index if not exists incident_drawings_updated_idx on public.incident_drawings(updated_at desc);

alter table public.incident_drawings enable row level security;

drop policy if exists "verified read incident drawings" on public.incident_drawings;
create policy "verified read incident drawings" on public.incident_drawings
for select to authenticated
using (
  exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled)
  and exists(select 1 from public.incidents i where i.id=incident_id and i.active)
);

drop policy if exists "verified create incident drawings" on public.incident_drawings;
create policy "verified create incident drawings" on public.incident_drawings
for insert to authenticated
with check (
  created_by=auth.uid()
  and exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled)
  and exists(select 1 from public.incidents i where i.id=incident_id and i.active)
);

drop policy if exists "owner update incident drawings" on public.incident_drawings;
create policy "owner update incident drawings" on public.incident_drawings
for update to authenticated
using (
  created_by=auth.uid()
  or exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK')
)
with check (
  created_by=auth.uid()
  or exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK')
);

drop policy if exists "owner delete incident drawings" on public.incident_drawings;
create policy "owner delete incident drawings" on public.incident_drawings
for delete to authenticated
using (
  created_by=auth.uid()
  or exists(select 1 from public.firemap_accounts a where a.user_id=auth.uid() and a.enabled and a.role='SK')
);

create or replace function public.firemap_touch_drawing()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists incident_drawings_touch on public.incident_drawings;
create trigger incident_drawings_touch
before update on public.incident_drawings
for each row execute function public.firemap_touch_drawing();

-- Zamknięcie zdarzenia w panelu SK czyści całą jego warstwę taktyczną.
create or replace function public.firemap_cleanup_closed_incident_drawings()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if old.active is true and new.active is false then
    delete from public.incident_drawings where incident_id=new.id;
  end if;
  return new;
end $$;

drop trigger if exists cleanup_incident_drawings_on_close on public.incidents;
create trigger cleanup_incident_drawings_on_close
after update of active on public.incidents
for each row execute function public.firemap_cleanup_closed_incident_drawings();

-- Realtime dla wszystkich map FIREMAP.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='incident_drawings'
  ) then
    alter publication supabase_realtime add table public.incident_drawings;
  end if;
end $$;
