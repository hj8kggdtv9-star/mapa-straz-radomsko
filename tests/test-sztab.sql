begin;
do $$
declare r text;u uuid;
begin
 foreach r in array array['HQ1','HQ2','UNIT','SK'] loop
  u:=gen_random_uuid();perform set_config('test.'||lower(r),u::text,true);
  insert into auth.users(id,aud,role,email,created_at,updated_at) values(u,'authenticated','authenticated','test-'||u||'@example.invalid',now(),now());
  insert into public.firemap_accounts(user_id,role,unit_name) values(u,case when r like 'HQ%' then 'SZTAB' else r end,'TEST ROLLBACK '||r);
 end loop;
end $$;
set local role authenticated;
do $$
declare r text;inc uuid;c record;s record;n integer;
begin
 foreach r in array array['hq1','hq2'] loop
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.'||r),'role','authenticated','email',r||'@example.invalid')::text,true);
  insert into public.incidents(kind,lat,lng,description) values('FIRE',52.1,21.1,'TEST ROLLBACK SZTAB') returning id into inc;
  perform set_config('test.inc_'||r,inc::text,true);
  if not exists(select 1 from public.incidents where id=inc and sztab_id=auth.uid()) then raise exception 'Missing automatic owner';end if;
  select * into c from public.create_incident_join_code(inc);
  if c.code !~ '^[0-9]{6}$' or c.expires_at<>now()+interval '7 days' then raise exception 'Wrong code / TTL';end if;
  perform set_config('test.code_'||r,c.code,true);
  perform set_config('test.codeid_'||r,c.join_code_id::text,true);
 end loop;
 -- HQ2 cannot read, close, issue codes for, or revoke the code of HQ1.
 if exists(select 1 from public.incidents where id=current_setting('test.inc_hq1')::uuid) then raise exception 'Cross-headquarters incident leak';end if;
 update public.incidents set active=false where id=current_setting('test.inc_hq1')::uuid;
 get diagnostics n=row_count;if n<>0 then raise exception 'Cross-headquarters write';end if;
 begin
  perform public.create_incident_join_code(current_setting('test.inc_hq1')::uuid);
  raise exception 'Cross-headquarters code allowed';
 exception when raise_exception then if sqlerrm='Cross-headquarters code allowed' then raise;end if;end;
 begin
  perform public.deactivate_incident_join_code(current_setting('test.codeid_hq1')::uuid);
  raise exception 'Cross-headquarters revoke allowed';
 exception when raise_exception then if sqlerrm='Cross-headquarters revoke allowed' then raise;end if;end;
 begin
  insert into public.incidents(kind,lat,lng,sztab_id) values('FIRE',52,21,current_setting('test.hq1')::uuid);
  raise exception 'Forged owner allowed';
 exception when insufficient_privilege then null;end;
 begin
  update public.incidents set sztab_id=null where id=current_setting('test.inc_hq2')::uuid;
  raise exception 'Owner removal allowed';
 exception when insufficient_privilege then null;end;
end $$;
set local role anon;
do $$
declare r text;s record;
begin
 perform set_config('request.jwt.claims','{}',true);
 foreach r in array array['hq1','hq2'] loop
  select * into s from public.external_force_join(current_setting('test.code_'||r),'WOO','USAR','Mazowieckie','warszawski','TEST ROLLBACK '||r,r,'GBA');
  if s.expires_at<>now()+interval '7 days' then raise exception 'Session unexpectedly limited';end if;
  perform set_config('test.token_'||r,s.session_token,true);
  perform set_config('test.vehicle_'||r,s.vehicle_id::text,true);
  perform public.external_force_update(s.session_token,52.1,21.1,'DISPATCHED');
 end loop;
end $$;
set local role authenticated;
do $$
declare n integer;c record;
begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.hq1'),'role','authenticated')::text,true);
 if not exists(select 1 from public.vehicles where id=current_setting('test.vehicle_hq1')::uuid) then raise exception 'Own QR vehicle missing';end if;
 if exists(select 1 from public.vehicles where id=current_setting('test.vehicle_hq2')::uuid) then raise exception 'Other HQ vehicle leaked';end if;
 if not exists(select 1 from public.external_force_sessions where vehicle_id=current_setting('test.vehicle_hq1')::uuid) then raise exception 'Own session missing';end if;
 if exists(select 1 from public.external_force_sessions where vehicle_id=current_setting('test.vehicle_hq2')::uuid) then raise exception 'Other session leaked';end if;
 if exists(select 1 from public.incident_join_codes where id=current_setting('test.codeid_hq2')::uuid) then raise exception 'Other code leaked';end if;
 update public.incidents set active=false where id=current_setting('test.inc_hq1')::uuid;
 get diagnostics n=row_count;if n<>1 then raise exception 'Own close failed';end if;
 if exists(select 1 from public.external_force_sessions where vehicle_id=current_setting('test.vehicle_hq1')::uuid and active) then raise exception 'Close did not expire session';end if;
 if exists(select 1 from public.incident_join_codes where id=current_setting('test.codeid_hq1')::uuid and active) then raise exception 'Close did not invalidate code';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.unit'),'role','authenticated')::text,true);
 if (select count(*) from public.vehicles where id in(current_setting('test.vehicle_hq1')::uuid,current_setting('test.vehicle_hq2')::uuid))<>2 then raise exception 'Existing UNIT visibility changed';end if;
 begin
  perform public.create_incident_join_code(current_setting('test.inc_hq2')::uuid);
  raise exception 'UNIT issued code';
 exception when raise_exception then if sqlerrm='UNIT issued code' then raise;end if;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.sk'),'role','authenticated')::text,true);
 select * into c from public.create_incident_join_code(current_setting('test.inc_hq2')::uuid,20000);
 if c.expires_at<>now()+interval '7 days' then raise exception 'TTL maximum failed';end if;
end $$;
set local role anon;
do $$
begin
 perform set_config('request.jwt.claims','{}',true);
 begin
  perform public.external_force_update(current_setting('test.token_hq1'),52.1,21.1,'ON_SCENE');
  raise exception 'Closed session accepted';
 exception when raise_exception then if sqlerrm='Closed session accepted' then raise;end if;end;
end $$;
rollback;
select 'PASS: two isolated headquarters, owner protection, QR vehicles, 7-day codes/sessions, closure, existing UNIT/SK access. Fixtures rolled back.' as result;
