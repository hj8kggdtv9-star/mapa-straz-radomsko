begin;
do $fixture$
declare inc uuid; other_inc uuid; c text; c2 text; a record;b record;x record;
begin
 insert into public.incidents(kind,lat,lng,description) values('MZ',52.23,21.01,'TEST QR PEERS rollback') returning id into inc;
 insert into public.incidents(kind,lat,lng,description) values('MZ',52.24,21.02,'TEST QR OTHER rollback') returning id into other_inc;
 select lpad(n::text,6,'0') into c from generate_series(0,999999) n where not exists(select 1 from public.incident_join_codes j where j.code=lpad(n::text,6,'0')) limit 1;
 insert into public.incident_join_codes(incident_id,code,expires_at) values(inc,c,now()+interval '1 hour');
 select lpad(n::text,6,'0') into c2 from generate_series(0,999999) n where not exists(select 1 from public.incident_join_codes j where j.code=lpad(n::text,6,'0')) limit 1;
 insert into public.incident_join_codes(incident_id,code,expires_at) values(other_inc,c2,now()+interval '1 hour');
 select * into a from public.external_force_join(c,'WOO',null,'Mazowieckie','TEST','TEST A','QR-A','GBA');
 select * into b from public.external_force_join(c,'COO','DRONE','Mazowieckie','TEST','TEST B','QR-B','GCBA');
 select * into x from public.external_force_join(c2,'EXTERNAL',null,'Mazowieckie','TEST','TEST X','QR-X','GBA');
 perform public.external_force_update(a.session_token,52.23,21.01,'DISPATCHED',5,0,null);
 perform public.external_force_update(b.session_token,52.23,21.01,'ON_SCENE',5,0,null);
 perform public.external_force_update(x.session_token,52.24,21.02,'DISPATCHED',5,0,null);
 insert into public.vehicles(id,unit_name,call_sign,vehicle_type,lat,lng,status,incident_id) values(gen_random_uuid(),'TEST LOCAL','QR-LOCAL','GBA',52.23,21.01,'ON_SCENE',inc);
 perform set_config('firemap_test.a',a.session_token,true);perform set_config('firemap_test.b',b.session_token,true);
 perform set_config('firemap_test.inc',inc::text,true);
end;$fixture$;
set local role anon;
do $test$
declare a text:=current_setting('firemap_test.a');b text:=current_setting('firemap_test.b'); rejected boolean:=false;
begin
 if (select count(*) from public.external_force_peers(a))<>2 then raise exception 'FAIL A peer count';end if;
 if not exists(select 1 from public.external_force_peers(a) p where p.call_sign='QR-B' and p.status='ON_SCENE' and p.force_group='COO' and p.specialist_group='DRONE' and p.lat=52.23) then raise exception 'FAIL A sees B';end if;
 if not exists(select 1 from public.external_force_peers(b) p where p.call_sign='QR-A') then raise exception 'FAIL B sees A';end if;
 if exists(select 1 from public.external_force_peers(a) p where p.call_sign in('QR-A','QR-X')) then raise exception 'FAIL self or other incident leaked';end if;
 perform public.external_force_update(b,52.25,21.03,'RETURNING',5,0,null);
 if not exists(select 1 from public.external_force_peers(a) p where p.call_sign='QR-B' and p.status='RETURNING' and p.lat=52.25) then raise exception 'FAIL changed position/status';end if;
 begin perform public.external_force_peers(repeat('0',48));exception when others then if sqlerrm='Sesja wygasła' then rejected:=true;else raise;end if;end;
 if not rejected then raise exception 'FAIL invalid token';end if;
 perform public.external_force_leave(b);
 if exists(select 1 from public.external_force_peers(a) p where p.call_sign='QR-B') then raise exception 'FAIL left peer visible';end if;
end;$test$;
reset role;
update public.incidents set active=false where id=current_setting('firemap_test.inc')::uuid;
set local role anon;
do $test$
declare rejected boolean:=false;
begin
 begin perform public.external_force_peers(current_setting('firemap_test.a'));exception when others then if sqlerrm='Sesja wygasła' then rejected:=true;else raise;end if;end;
 if not rejected then raise exception 'FAIL closed incident readable';end if;
end;$test$;
reset role;
rollback;
select 'PASS: two QR sessions as anon, mutual visibility, same-location peers, local OSP, GPS/status update, self/other incident isolation, leave, invalid token, incident closure. All fixtures rolled back.' as result;