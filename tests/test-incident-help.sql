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
 if (select count(*) from public.external_force_peers(current_setting('test.token_one')))<>2 then raise exception 'HQ peers isolation failed';end if;
end $$;

set local role anon;
do $$declare id uuid;again uuid;r jsonb;begin
 id:=public.firemap_help_raise(current_setting('test.inc_hq1')::uuid,'TEST POMOC',current_setting('test.token_one'));
 perform set_config('test.help',id::text,true);
 again:=public.firemap_help_raise(current_setting('test.inc_hq1')::uuid,'TEST POMOC',current_setting('test.token_one'));
 if again<>id then raise exception 'Duplicate help request';end if;
 r:=public.firemap_help_read(current_setting('test.token_two'));
 if jsonb_array_length(r)<>1 or (r->0->>'can_clear')::boolean then raise exception 'Guest read/ownership failed';end if;
 if jsonb_array_length(public.firemap_help_read(current_setting('test.token_foreign')))<>0 then raise exception 'Help leaked to foreign HQ';end if;
 if jsonb_array_length(public.firemap_help_read(current_setting('test.token_second')))<>0 then raise exception 'Help leaked to another incident';end if;
 begin perform public.firemap_help_raise(current_setting('test.inc_hq2')::uuid,'',current_setting('test.token_one'));raise exception 'Foreign raise allowed';exception when raise_exception then if sqlerrm='Foreign raise allowed' then raise;end if;end;
 begin perform public.firemap_help_clear(id,current_setting('test.token_two'));raise exception 'Foreign clear allowed';exception when raise_exception then if sqlerrm='Foreign clear allowed' then raise;end if;end;
 begin perform public.firemap_help_read(repeat('0',48));raise exception 'Bad token allowed';exception when raise_exception then if sqlerrm='Bad token allowed' then raise;end if;end;
 begin perform public.firemap_help_read();raise exception 'Anonymous read allowed';exception when raise_exception then if sqlerrm='Anonymous read allowed' then raise;end if;end;
 begin perform public.firemap_help_raise(current_setting('test.inc_hq1')::uuid,repeat('x',161),current_setting('test.token_one'));raise exception 'Oversize allowed';exception when raise_exception then if sqlerrm='Oversize allowed' then raise;end if;end;
end $$;
set local role authenticated;
do $$declare id uuid;r jsonb;begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.hq1'),'role','authenticated')::text,true);
 r:=public.firemap_help_read();if jsonb_array_length(r)<>1 or not (r->0->>'can_clear')::boolean then raise exception 'HQ read/clear permission failed';end if;
 id:=public.firemap_help_raise(current_setting('test.inc_hq1')::uuid,'TEST SK');
 perform public.firemap_help_clear(current_setting('test.help')::uuid);
 if jsonb_array_length(public.firemap_help_read())<>1 then raise exception 'HQ clear failed';end if;
 update public.incidents i set active=false where i.id=current_setting('test.inc_hq1')::uuid;
 if jsonb_array_length(public.firemap_help_read())<>0 then raise exception 'Closed event help visible';end if;
end $$;
set local role anon;
do $$begin
 begin perform public.firemap_help_raise(current_setting('test.inc_hq1')::uuid,'',current_setting('test.token_one'));raise exception 'Closed help allowed';exception when raise_exception then if sqlerrm='Closed help allowed' then raise;end if;end;
end $$;
rollback;
select 'PASS: HELP guest/HQ visibility, exact incident isolation, idempotency, owner and HQ cancellation, invalid token, anonymous denial, input limit and closure' as result;
