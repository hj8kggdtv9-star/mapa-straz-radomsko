-- QR guests may read only vehicles belonging to their active incident.
-- Existing high-entropy session tokens authorize this endpoint; no table grants are widened.
create or replace function public.external_force_peers(p_session_token text)
returns table(id uuid,call_sign text,unit_name text,vehicle_type text,status text,lat double precision,lng double precision,updated_at timestamptz,force_group text,specialist_group text)
language plpgsql stable security definer set search_path=''
as $fn$
declare s public.external_force_sessions%rowtype;
begin
 if p_session_token is null or length(p_session_token)<>48 then
  raise exception 'Sesja wygasła';
 end if;
 select e.* into s from public.external_force_sessions e
 where e.token_hash=extensions.digest(p_session_token,'sha256') and e.active and e.expires_at>now();
 if s.id is null or not exists(select 1 from public.incidents i where i.id=s.incident_id and i.active) then
  raise exception 'Sesja wygasła';
 end if;
 return query
 select v.id,v.call_sign,v.unit_name,v.vehicle_type,v.status,v.lat,v.lng,v.updated_at,v.force_group,v.specialist_group
 from public.vehicles v
 where v.incident_id=s.incident_id and v.id<>s.vehicle_id and v.status<>'BASE'
 and v.lat between -90 and 90 and v.lng between -180 and 180
 and (v.external_session_id is null or exists(
  select 1 from public.external_force_sessions peer
  where peer.id=v.external_session_id and peer.vehicle_id=v.id and peer.incident_id=s.incident_id
  and peer.active and peer.expires_at>now()
 ))
 order by v.id;
end;
$fn$;
revoke all on function public.external_force_peers(text) from public;
grant execute on function public.external_force_peers(text) to anon,authenticated;
