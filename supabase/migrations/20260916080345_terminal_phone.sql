set local lock_timeout='3s';
set local statement_timeout='30s';
alter table public.vehicles add column contact_phone text;
alter table public.vehicles add constraint vehicle_contact_phone_format check(contact_phone is null or contact_phone ~ '^\+?[0-9]{7,15}$');
-- Existing RLS determines who can see a vehicle and its optional contact number.
create function public.external_force_peers_with_contact(p_session_token text)
returns table(id uuid,call_sign text,unit_name text,vehicle_type text,status text,lat float8,lng float8,updated_at timestamptz,force_group text,specialist_group text,contact_phone text)
language sql stable security definer set search_path='' as $$
 select p.*,v.contact_phone from public.external_force_peers(p_session_token) p join public.vehicles v on v.id=p.id;
$$;
revoke all on function public.external_force_peers_with_contact(text) from public;
grant execute on function public.external_force_peers_with_contact(text) to anon,authenticated;
create function public.external_force_set_contact(p_session_token text,p_phone text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare s public.external_force_sessions%rowtype;n integer;
begin
 s:=firemap_private.guest_session(p_session_token);
 if p_phone is not null and p_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'Nieprawidłowy numer telefonu';end if;
 perform 1 from public.incidents where id=s.incident_id and active for share;
 if not found then raise exception 'Sesja wygasła';end if;
 perform 1 from public.external_force_sessions where id=s.id and active and expires_at>now() for update;
 if not found then raise exception 'Sesja wygasła';end if;
 update public.vehicles set contact_phone=p_phone where id=s.vehicle_id and external_session_id=s.id and incident_id=s.incident_id;
 get diagnostics n=row_count;if n<>1 then raise exception 'Brak pojazdu sesji';end if;
 return true;
end $$;
revoke all on function public.external_force_set_contact(text,text) from public;
grant execute on function public.external_force_set_contact(text,text) to anon,authenticated;
