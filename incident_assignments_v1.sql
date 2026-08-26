-- FIREMAP — przypisywanie zastępów do aktywnych zdarzeń
-- Uruchom raz w Supabase SQL Editor.

alter table public.vehicles
  add column if not exists incident_id uuid references public.incidents(id) on delete set null;

create index if not exists vehicles_incident_id_idx on public.vehicles(incident_id);

-- Zastęp może aktualizować własny rekord pojazdu zgodnie z istniejącymi politykami vehicles.
-- SK odczytuje incident_id razem z pozostałymi danymi pojazdu.
-- Realtime dla vehicles jest już używany przez FIREMAP.
