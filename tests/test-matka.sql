begin;
do $$declare c uuid;u uuid;r text;begin
 select id into c from public.firemap_counties where slug='lodzkie-radomszczanski';
 foreach r in array array['admin','unit','outsider'] loop
  u:=gen_random_uuid();insert into auth.users(id,email) values(u,'test-'||u||'@example.invalid');perform set_config('test.'||r,u::text,true);
  if r='admin' then insert into public.firemap_platform_admins values(u);
  else insert into public.firemap_accounts(user_id,role,unit_name,enabled,county_id,login_email) values(u,'UNIT','TEST MATKA',true,c,'test-'||u||'@example.invalid');end if;
 end loop;
end $$;
set local role authenticated;
do $$begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.admin'),'role','authenticated')::text,true);
 if (select count(*) from public.vehicles)<>0 or (select count(*) from public.incidents)<>0 or (select count(*) from public.incident_drawings)<>0 then raise exception 'Admin has operational access';end if;
 begin perform public.firemap_admin_account_change(current_setting('test.admin')::uuid,current_setting('test.unit')::uuid,'disable');raise exception 'Public mutation allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare a uuid:=current_setting('test.admin')::uuid;u uuid:=current_setting('test.unit')::uuid;login text;begin
 begin perform public.firemap_admin_account_change(current_setting('test.outsider')::uuid,u,'disable');raise exception 'Unauthorized actor allowed';exception when raise_exception then if sqlerrm='Unauthorized actor allowed' then raise;end if;end;
 begin perform public.firemap_admin_account_change(a,a,'disable');raise exception 'Admin self lockout allowed';exception when raise_exception then if sqlerrm='Admin self lockout allowed' then raise;end if;end;
 perform public.firemap_admin_account_change(a,u,'disable');
 if (select enabled from public.firemap_accounts where user_id=u) then raise exception 'Disable failed';end if;
 perform public.firemap_admin_account_change(a,u,'enable');
 perform public.firemap_admin_account_change(a,u,'rename','TEST RENAMED');
 if (select unit_name from public.firemap_accounts where user_id=u)<>'TEST RENAMED' then raise exception 'Rename failed';end if;
 select login_email into login from public.firemap_accounts where user_id=u;
 begin perform public.firemap_admin_account_change(a,u,'archive',null,null,'wrong');raise exception 'Wrong confirmation allowed';exception when raise_exception then if sqlerrm='Wrong confirmation allowed' then raise;end if;end;
 perform public.firemap_admin_account_change(a,u,'archive',null,null,login);
 if not exists(select 1 from public.firemap_accounts where user_id=u and not enabled and archived_at is not null) then raise exception 'Archive failed';end if;
 begin perform public.firemap_admin_account_change(a,u,'enable');raise exception 'Archived reenabled';exception when raise_exception then if sqlerrm='Archived reenabled' then raise;end if;end;
end $$;
set local role authenticated;
do $$begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.unit'),'role','authenticated')::text,true);
 if public.firemap_operational_account_active() then raise exception 'Archived JWT active';end if;
 if (select count(*) from public.vehicles)<>0 or (select count(*) from public.incidents)<>0 then raise exception 'Archived JWT has data';end if;
end $$;
rollback;
select 'PASS: MATKA has no operational data, only service mutation, actor checks, administrator protection, disable/enable/rename/archive and archived JWT denial' as result;
