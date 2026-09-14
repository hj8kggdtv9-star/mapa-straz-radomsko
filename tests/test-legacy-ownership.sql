-- Local fixture only; run after local-db-test.cjs seeds and migrates its database.
begin;
update public.vehicles set account_id=null where id='00000000-0000-4000-8000-000000000010';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$declare n integer;begin
 update public.vehicles set status='DISPATCHED' where id='00000000-0000-4000-8000-000000000010';
 get diagnostics n=row_count;
 if n<>0 then raise exception 'Unowned legacy row unexpectedly writable';end if;
 begin
  insert into public.vehicles(id,unit_name,call_sign,vehicle_type,lat,lng,status)
  values('00000000-0000-4000-8000-000000000010','OSP Test','TEST-1','GBA',51,19,'DISPATCHED')
  on conflict(id) do update set status=excluded.status;
  raise exception 'Legacy upsert unexpectedly bypassed ownership';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Simulate an administrator's explicit, verified assignment; never infer by display name.
update public.vehicles set account_id='00000000-0000-4000-8000-000000000002' where id='00000000-0000-4000-8000-000000000010';
set local role authenticated;
do $$declare n integer;begin
 update public.vehicles set status='DISPATCHED' where id='00000000-0000-4000-8000-000000000010';
 get diagnostics n=row_count;
 if n<>1 then raise exception 'Verified assignment did not restore vehicle writes';end if;
end $$;
rollback;
select 'PASS: legacy record remains protected; explicit owner assignment restores writes' as result;
