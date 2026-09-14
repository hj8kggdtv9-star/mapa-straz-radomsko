-- Read-only preflight; contains no account passwords, tokens or vehicle coordinates.
select
 (select count(*) from public.vehicles where account_id is null and external_session_id is null) as unowned_local_vehicles,
 (select count(*) from public.firemap_accounts where county_id is null) as accounts_without_county,
 (select count(*) from auth.users u where u.email like '%@firemap.local' and not exists(select 1 from public.firemap_accounts a where a.user_id=u.id)) as auth_without_profile;
select v.id as vehicle_id, v.status,
 (select count(*) from public.firemap_accounts a where a.county_id=v.county_id and a.unit_name=v.unit_name and a.role in ('UNIT','JRG') and a.enabled) as matching_active_accounts
from public.vehicles v where v.account_id is null and v.external_session_id is null;
