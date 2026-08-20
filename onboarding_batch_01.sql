-- FIREMAP — onboarding batch 01
-- Najpierw utwórz poniższych użytkowników w Supabase Authentication -> Users.
-- Każdemu nadaj INDYWIDUALNE hasło i zaznacz Auto confirm user.
-- Następnie uruchom cały ten plik w SQL Editor.
-- HASEŁ NIE WPISUJEMY DO TEGO PLIKU ANI DO GITHUBA.

-- Konta techniczne do utworzenia:
-- osp.kodrab@firemap.local            -> OSP Kodrąb
-- osp.dobryszyce@firemap.local        -> OSP Dobryszyce
-- osp.radziechowice.drugie@firemap.local -> OSP Radziechowice Drugie
-- osp.przedborz@firemap.local          -> OSP Przedbórz
-- osp.stobiecko.miejskie@firemap.local -> OSP Stobiecko Miejskie
-- osp.strzalkow@firemap.local          -> OSP Strzałków
-- osp.wielgomlyny@firemap.local        -> OSP Wielgomłyny
-- osp.silnica@firemap.local            -> OSP Silnica
-- osp.kobiele.wielkie@firemap.local    -> OSP Kobiele Wielkie
-- osp.chrzanowice@firemap.local        -> OSP Chrzanowice

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Kodrąb','UNIT',true from auth.users where email='osp.kodrab@firemap.local'
on conflict(user_id) do update set unit_name='OSP Kodrąb',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Dobryszyce','UNIT',true from auth.users where email='osp.dobryszyce@firemap.local'
on conflict(user_id) do update set unit_name='OSP Dobryszyce',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Radziechowice Drugie','UNIT',true from auth.users where email='osp.radziechowice.drugie@firemap.local'
on conflict(user_id) do update set unit_name='OSP Radziechowice Drugie',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Przedbórz','UNIT',true from auth.users where email='osp.przedborz@firemap.local'
on conflict(user_id) do update set unit_name='OSP Przedbórz',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Stobiecko Miejskie','UNIT',true from auth.users where email='osp.stobiecko.miejskie@firemap.local'
on conflict(user_id) do update set unit_name='OSP Stobiecko Miejskie',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Strzałków','UNIT',true from auth.users where email='osp.strzalkow@firemap.local'
on conflict(user_id) do update set unit_name='OSP Strzałków',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Wielgomłyny','UNIT',true from auth.users where email='osp.wielgomlyny@firemap.local'
on conflict(user_id) do update set unit_name='OSP Wielgomłyny',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Silnica','UNIT',true from auth.users where email='osp.silnica@firemap.local'
on conflict(user_id) do update set unit_name='OSP Silnica',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Kobiele Wielkie','UNIT',true from auth.users where email='osp.kobiele.wielkie@firemap.local'
on conflict(user_id) do update set unit_name='OSP Kobiele Wielkie',role='UNIT',enabled=true;

insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select id,'OSP Chrzanowice','UNIT',true from auth.users where email='osp.chrzanowice@firemap.local'
on conflict(user_id) do update set unit_name='OSP Chrzanowice',role='UNIT',enabled=true;

-- Kontrola: powinno zwrócić utworzone/przypisane konta tej partii.
select a.unit_name,a.role,a.enabled,u.email
from public.firemap_accounts a
join auth.users u on u.id=a.user_id
where u.email in (
'osp.kodrab@firemap.local','osp.dobryszyce@firemap.local','osp.radziechowice.drugie@firemap.local','osp.przedborz@firemap.local','osp.stobiecko.miejskie@firemap.local','osp.strzalkow@firemap.local','osp.wielgomlyny@firemap.local','osp.silnica@firemap.local','osp.kobiele.wielkie@firemap.local','osp.chrzanowice@firemap.local'
)
order by a.unit_name;
