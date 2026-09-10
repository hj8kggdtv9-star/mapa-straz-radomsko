begin;
do $$declare c uuid;u uuid;r text;begin
 select id into c from public.firemap_counties where slug='lodzkie-radomszczanski';perform set_config('test.county1',c::text,true);
 insert into public.firemap_counties(slug,province,name,default_area) values('test-'||substr(gen_random_uuid()::text,1,8),'TEST','TEST powiat','{}') returning id into c;perform set_config('test.county2',c::text,true);
 foreach r in array array['sk1','unit1','sk2','unit2','hq1'] loop
  if r='sk1' then select user_id into u from public.firemap_accounts a join auth.users x on x.id=a.user_id where x.email='sk@firemap.local';
  else
   u:=gen_random_uuid();insert into auth.users(id,email) values(u,'test-'||u||'@example.invalid');
   insert into public.firemap_accounts(user_id,role,unit_name,county_id,login_email) values(u,case when r='sk2' then 'SK' when r='hq1' then 'SZTAB' else 'UNIT' end,'TEST COUNTY '||r,current_setting('test.county'||case when r in ('sk2','unit2') then '2' else '1' end)::uuid,'test-'||u||'@example.invalid');
  end if;
  perform set_config('test.'||r,u::text,true);
 end loop;
end $$;
set local role authenticated;
do $$declare r text;i uuid;c record;v uuid;n integer;begin
 foreach r in array array['sk1','sk2','hq1'] loop
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.'||r),'role','authenticated')::text,true);
  insert into public.incidents(kind,lat,lng,description) values('FIRE',53.1,22.1,'TEST COUNTY') returning id into i;perform set_config('test.inc_'||r,i::text,true);
  select * into c from public.create_incident_join_code(i);perform set_config('test.code_'||r,c.code,true);perform set_config('test.codeid_'||r,c.join_code_id::text,true);
  if c.expires_at<>now()+interval '7 days' then raise exception 'Wrong TTL';end if;
 end loop;
 foreach r in array array['unit1','unit2'] loop
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.'||r),'role','authenticated')::text,true);
  v:=gen_random_uuid();perform set_config('test.v_'||r,v::text,true);
  -- Old client payload, including forged county/account: trigger must bind genuine identity.
  insert into public.vehicles(id,unit_name,call_sign,vehicle_type,status,lat,lng,account_id,county_id) values(v,'TEST COUNTY '||r,'TEST-1','GBA','DISPATCHED',53.1,22.1,current_setting('test.sk1')::uuid,current_setting('test.county1')::uuid);
  if not exists(select 1 from public.vehicles where id=v and account_id=auth.uid() and county_id=public.firemap_county_id()) then raise exception 'Owner binding failed';end if;
  insert into public.vehicles(id,unit_name,call_sign,vehicle_type,status,lat,lng) values(v,'TEST COUNTY '||r,'TEST-1','GBA','ON_SCENE',53.2,22.2) on conflict(id) do update set lat=excluded.lat,lng=excluded.lng,status=excluded.status;
  if not exists(select 1 from public.vehicles where id=v and status='ON_SCENE' and lat=53.2) then raise exception 'Legacy GPS upsert failed';end if;
 end loop;
 if exists(select 1 from public.vehicles where id=current_setting('test.v_unit1')::uuid) then raise exception 'Unit cross-county read leak';end if;
 begin
  insert into public.vehicles(id,unit_name,call_sign,vehicle_type,status,lat,lng) values(current_setting('test.v_unit1')::uuid,'TEST','TEST-1','GBA','BASE',53,22) on conflict(id) do update set status=excluded.status;
  raise exception 'Cross-account upsert allowed';
 exception when insufficient_privilege then null;when raise_exception then if sqlerrm='Cross-account upsert allowed' then raise;end if;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.sk2'),'role','authenticated')::text,true);
 if exists(select 1 from public.incidents where id=current_setting('test.inc_sk1')::uuid) then raise exception 'SK incident leak';end if;
 if exists(select 1 from public.firemap_accounts where user_id=current_setting('test.unit1')::uuid) then raise exception 'SK account leak';end if;
 if not exists(select 1 from public.firemap_accounts where user_id=current_setting('test.unit2')::uuid) then raise exception 'SK cannot manage own unit';end if;
 if exists(select 1 from public.incident_join_codes where id=current_setting('test.codeid_sk1')::uuid) then raise exception 'Code read leak';end if;
 update public.incidents set active=false where id=current_setting('test.inc_sk1')::uuid;get diagnostics n=row_count;if n<>0 then raise exception 'Cross-county close';end if;
 begin perform public.create_incident_join_code(current_setting('test.inc_sk1')::uuid);raise exception 'Cross-county code issued';exception when raise_exception then if sqlerrm='Cross-county code issued' then raise;end if;end;
 begin perform public.deactivate_incident_join_code(current_setting('test.codeid_sk1')::uuid);raise exception 'Cross-county code revoked';exception when raise_exception then if sqlerrm='Cross-county code revoked' then raise;end if;end;
 begin update public.incidents set county_id=current_setting('test.county1')::uuid where id=current_setting('test.inc_sk2')::uuid;raise exception 'County transfer allowed';exception when insufficient_privilege then null;end;
 -- Own county unit remains visible at GPS coordinates outside its county.
 if not exists(select 1 from public.vehicles where id=current_setting('test.v_unit2')::uuid and lat=53.2) then raise exception 'SK lost own GPS';end if;
 update public.vehicles set incident_id=current_setting('test.inc_sk2')::uuid where id=current_setting('test.v_unit2')::uuid;
 get diagnostics n=row_count;if n<>1 then raise exception 'SK assignment failed';end if;
end $$;
set local role anon;
do $$declare s record;t record;begin
 perform set_config('request.jwt.claims','{}',true);
 if exists(select 1 from public.vehicles) then raise exception 'Anonymous operational read';end if;
 select * into s from public.external_force_join(current_setting('test.code_sk2'),'LOCAL',null,'TEST','TEST','TEST QR LOCAL','QR-L','GBA');
 perform set_config('test.guest',s.session_token,true);perform set_config('test.guest_id',s.vehicle_id::text,true);
 perform public.external_force_update(s.session_token,53.3,22.3,'DISPATCHED');
 select * into t from public.external_force_join(current_setting('test.code_sk2'),'WOO',null,'TEST','TEST','TEST QR WOO','QR-W','GBA');
 perform public.external_force_update(t.session_token,53.3,22.3,'ON_SCENE');
 if (select count(*) from public.external_force_peers(s.session_token))<>2 then raise exception 'QR peers missing own local/WOO forces';end if;
end $$;
set local role authenticated;
do $$declare n integer;begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.sk1'),'role','authenticated')::text,true);
 if exists(select 1 from public.vehicles where id=current_setting('test.guest_id')::uuid) then raise exception 'Guest leaked to other county';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.hq1'),'role','authenticated')::text,true);
 if exists(select 1 from public.vehicles where id=current_setting('test.v_unit1')::uuid) then raise exception 'HQ sees unrelated local vehicle';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.sk2'),'role','authenticated')::text,true);
 if not exists(select 1 from public.vehicles where id=current_setting('test.guest_id')::uuid and county_id=public.firemap_county_id()) then raise exception 'QR not bound to incident county';end if;
 update public.incidents set active=false where id=current_setting('test.inc_sk2')::uuid;
 if exists(select 1 from public.external_force_sessions where incident_id=current_setting('test.inc_sk2')::uuid and active) then raise exception 'Close did not expire guests';end if;
end $$;
rollback;
select 'PASS: county isolation, legacy GPS upsert outside old bounds, ownership, account listing, incident assignment, cross-county RPC denial, LOCAL/WOO QR peers, HQ isolation and closure; no persistent test data' as result;
