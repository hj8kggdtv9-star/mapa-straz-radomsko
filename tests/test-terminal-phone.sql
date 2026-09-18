begin;
do $$declare c uuid;u uuid;r text;begin
 select id into c from public.firemap_counties where slug='lodzkie-radomszczanski';
 foreach r in array array['hq1','hq2'] loop
  u:=gen_random_uuid();insert into auth.users(id,email) values(u,'test-'||u||'@example.invalid');
  insert into public.firemap_accounts(user_id,role,unit_name,county_id,login_email) values(u,'SZTAB','TEST '||r,c,'sztab.'||r||'@firemap.local');
  perform set_config('test.'||r,u::text,true);
 end loop;
end $$;
set local role authenticated;
do $$declare r text;o jsonb;d integer;c record;begin
 foreach r in array array['hq1','hq2'] loop
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.'||r),'role','authenticated')::text,true);
  o:=public.start_hq_operation('TEST AKCJA','{"province":"Łódzkie","county":"powiat tomaszowski","bounds":[[51,19],[52,21]]}',30);
  perform set_config('test.inc_'||r,o->>'incident_id',true);perform set_config('test.code_'||r,o->>'code',true);
  if (o->>'expires_at')::timestamptz<>now()+interval '30 days' then raise exception '30 day duration failed';end if;
 end loop;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.hq1'),'role','authenticated')::text,true);
 declare
  second_id uuid;
 begin
  insert into public.incidents(kind,lat,lng,description) values('FIRE',52,20,'SECOND HQ INCIDENT') returning id into second_id;
  select * into c from public.create_incident_join_code(second_id,1440);
  perform set_config('test.code_second',c.code,true);
 end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.hq2'),'role','authenticated')::text,true);
 foreach d in array array[1,3,7,14,30] loop
  select * into c from public.create_incident_join_code(current_setting('test.inc_hq2')::uuid,d*1440);
  if c.expires_at<>now()+make_interval(days=>d) then raise exception 'Wrong duration';end if;
 end loop;
 begin perform public.create_incident_join_code(current_setting('test.inc_hq2')::uuid,43201);raise exception 'Overlong access allowed';exception when raise_exception then if sqlerrm='Overlong access allowed' then raise;end if;end;
 begin perform public.create_incident_join_code(current_setting('test.inc_hq1')::uuid,1440);raise exception 'Foreign HQ allowed';exception when raise_exception then if sqlerrm='Foreign HQ allowed' then raise;end if;end;
end $$;
set local role anon;
do $$declare r text;s record;out jsonb;row jsonb;id1 uuid:=gen_random_uuid();begin
 perform set_config('request.jwt.claims','{}',true);
 foreach r in array array['one','two','foreign','second'] loop
  select * into s from public.external_force_join(current_setting('test.code_'||case when r='foreign' then 'hq2' when r='second' then 'second' else 'hq1' end),'EXTERNAL',null,'TEST','TEST','TEST '||r,r,'GBA');
  perform set_config('test.token_'||r,s.session_token,true);perform set_config('test.session_'||r,s.session_id::text,true);
  perform public.external_force_update(s.session_token,54,23,'ON_SCENE');
 end loop;

 perform public.external_force_set_contact(current_setting('test.token_one'),'+48600123456');
 if not exists(select 1 from public.external_force_peers_with_contact(current_setting('test.token_two')) where contact_phone='+48600123456') then raise exception 'Same HQ contact missing';end if;
 if exists(select 1 from public.external_force_peers_with_contact(current_setting('test.token_foreign')) where contact_phone='+48600123456') then raise exception 'Foreign HQ contact leak';end if;
 begin perform public.external_force_set_contact(current_setting('test.token_one'),'javascript:bad');raise exception 'Invalid phone accepted';exception when raise_exception then if sqlerrm='Invalid phone accepted' then raise;end if;end;
 begin perform public.external_force_set_contact(repeat('0',48),'+48600123456');raise exception 'Invalid token contact allowed';exception when raise_exception then if sqlerrm='Invalid token contact allowed' then raise;end if;end;
 perform public.external_force_set_contact(current_setting('test.token_one'),null);
 if exists(select 1 from public.external_force_peers_with_contact(current_setting('test.token_two')) where contact_phone is not null) then raise exception 'Contact removal failed';end if;
 if (select count(*) from public.external_force_peers(current_setting('test.token_one')))<>2 then raise exception 'HQ peers isolation failed';end if;
 row:=jsonb_build_object('id',id1,'category','SECTOR','geometry_type','CIRCLE','geometry','{"center":[54,23],"radius":20}'::jsonb,'style','{"point":true,"pointName":"Hydrant","pointColor":"#2563eb"}'::jsonb,'label','Hydrant');
 perform set_config('test.drawing',id1::text,true);
 perform public.external_tactical_write(current_setting('test.token_one'),jsonb_build_array(row));
 out:=public.external_tactical_read(current_setting('test.token_two'));
 if jsonb_array_length(out->'drawings')<>1 then raise exception 'Shared tactics missing';end if;
 out:=public.external_tactical_read(current_setting('test.token_second'));
 if jsonb_array_length(out->'drawings')<>1 then raise exception 'Same HQ different incident tactics missing';end if;
 out:=public.external_tactical_read(current_setting('test.token_foreign'));
 if jsonb_array_length(out->'drawings')<>0 then raise exception 'Foreign HQ tactics leak';end if;
 begin perform public.external_tactical_write(current_setting('test.token_two'),jsonb_build_array(row));raise exception 'Foreign author edit allowed';exception when raise_exception then if sqlerrm='Foreign author edit allowed' then raise;end if;end;
 begin perform public.external_tactical_write(current_setting('test.token_foreign'),'[]',array[id1]);raise exception 'Foreign author delete allowed';exception when raise_exception then if sqlerrm='Foreign author delete allowed' then raise;end if;end;
 begin perform public.external_tactical_read(repeat('0',48));raise exception 'Invalid token allowed';exception when raise_exception then if sqlerrm='Invalid token allowed' then raise;end if;end;
 begin perform public.external_tactical_write(current_setting('test.token_one'),jsonb_build_array(row||'{"geometry":{"center":[54,23]}}'));raise exception 'Invalid geometry allowed';exception when raise_exception then if sqlerrm='Invalid geometry allowed' then raise;end if;end;
end $$;
set local role authenticated;
do $$begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.hq1'),'role','authenticated')::text,true);
 if not exists(select 1 from public.incident_drawings where id=current_setting('test.drawing')::uuid) then raise exception 'HQ cannot read guest tactics';end if;
 update public.incidents set active=false where id=current_setting('test.inc_hq1')::uuid;
end $$;
set local role anon;
do $$begin
 begin perform public.external_force_set_contact(current_setting('test.token_one'),'+48600123456');raise exception 'Closed contact write allowed';exception when raise_exception then if sqlerrm='Closed contact write allowed' then raise;end if;end;
 begin perform public.external_tactical_read(current_setting('test.token_one'));raise exception 'Closed access allowed';exception when raise_exception then if sqlerrm='Closed access allowed' then raise;end if;end;
 begin perform public.external_tactical_write(current_setting('test.token_one'),'[]');raise exception 'Closed write allowed';exception when raise_exception then if sqlerrm='Closed write allowed' then raise;end if;end;
end $$;
reset role;
update public.external_force_sessions set expires_at=now()-interval '1 minute' where id=current_setting('test.session_foreign')::uuid;
set local role anon;
do $$begin
 begin perform public.external_tactical_read(current_setting('test.token_foreign'));raise exception 'Expired read allowed';exception when raise_exception then if sqlerrm='Expired read allowed' then raise;end if;end;
 begin perform public.external_tactical_write(current_setting('test.token_foreign'),'[]');raise exception 'Expired write allowed';exception when raise_exception then if sqlerrm='Expired write allowed' then raise;end if;end;
end $$;
rollback;
select 'PASS: phone write/removal, peer contact visibility, foreign HQ isolation, invalid phone/token and closed-session denial; full HQ regression' as result;
