-- FIREMAP — ZBIORCZE PRZYPISANIE WSZYSTKICH KONT
-- Zakładamy, że użytkownicy zostali już utworzeni w Supabase Authentication -> Users.
-- Ten skrypt NIE ustawia ani nie przechowuje haseł.
-- Można uruchamiać go wielokrotnie.

with expected(email, unit_name, role) as (
  values
    ('sk@firemap.local','KP PSP Radomsko','SK'),
    ('jrg-radomsko@firemap.local','JRG Radomsko','JRG'),
    ('osp.babczow@firemap.local','OSP Babczów','UNIT'),
    ('osp.biestrzykow.m@firemap.local','OSP Biestrzyków M.','UNIT'),
    ('osp.bogwidzowy@firemap.local','OSP Bogwidzowy','UNIT'),
    ('osp.borzykowa@firemap.local','OSP Borzykowa','UNIT'),
    ('osp.brudzice@firemap.local','OSP Brudzice','UNIT'),
    ('osp.chelmo@firemap.local','OSP Chełmo','UNIT'),
    ('osp.chrzanowice@firemap.local','OSP Chrzanowice','UNIT'),
    ('osp.ciezkowice@firemap.local','OSP Ciężkowice','UNIT'),
    ('osp.dabrowka@firemap.local','OSP Dąbrówka','UNIT'),
    ('osp.dmenin@firemap.local','OSP Dmenin','UNIT'),
    ('osp.dobryszyce@firemap.local','OSP Dobryszyce','UNIT'),
    ('osp.dziepolc@firemap.local','OSP Dziepółć','UNIT'),
    ('osp.folwarki@firemap.local','OSP Folwarki','UNIT'),
    ('osp.gidle@firemap.local','OSP Gidle','UNIT'),
    ('osp.gomunice@firemap.local','OSP Gomunice','UNIT'),
    ('osp.gorzedow@firemap.local','OSP Gorzędów','UNIT'),
    ('osp.goslawice@firemap.local','OSP Gosławice','UNIT'),
    ('osp.gowarzow@firemap.local','OSP Gowarzów','UNIT'),
    ('osp.gory.mokre@firemap.local','OSP Góry Mokre','UNIT'),
    ('osp.granice@firemap.local','OSP Granice','UNIT'),
    ('osp.grodzisko@firemap.local','OSP Grodzisko','UNIT'),
    ('osp.jankowice@firemap.local','OSP Jankowice','UNIT'),
    ('osp.jedlno.drugie@firemap.local','OSP Jedlno Drugie','UNIT'),
    ('osp.jozefow.stary@firemap.local','OSP Józefów Stary','UNIT'),
    ('osp.kamiensk@firemap.local','OSP Kamieńsk','UNIT'),
    ('osp.karczow@firemap.local','OSP Karczów','UNIT'),
    ('osp.kietlin@firemap.local','OSP Kietlin','UNIT'),
    ('osp.kletnia@firemap.local','OSP Kletnia','UNIT'),
    ('osp.kobiele.wielkie@firemap.local','OSP Kobiele Wielkie','UNIT'),
    ('osp.kocierzowy@firemap.local','OSP Kocierzowy','UNIT'),
    ('osp.kodrab@firemap.local','OSP Kodrąb','UNIT'),
    ('osp.korytno@firemap.local','OSP Korytno','UNIT'),
    ('osp.kraszewice@firemap.local','OSP Kraszewice','UNIT'),
    ('osp.krepa@firemap.local','OSP Krępa','UNIT'),
    ('osp.krzetow@firemap.local','OSP Krzętów','UNIT'),
    ('osp.krzywanice@firemap.local','OSP Krzywanice','UNIT'),
    ('osp.lgota.wielka@firemap.local','OSP Lgota Wielka','UNIT'),
    ('osp.lipowczyce@firemap.local','OSP Lipowczyce','UNIT'),
    ('osp.ladzice@firemap.local','OSP Ładzice','UNIT'),
    ('osp.maluszyn@firemap.local','OSP Maluszyn','UNIT'),
    ('osp.mala.wies@firemap.local','OSP Mała Wieś','UNIT'),
    ('osp.maslowice@firemap.local','OSP Masłowice','UNIT'),
    ('osp.mysliwczow@firemap.local','OSP Myśliwczów','UNIT'),
    ('osp.orzechow@firemap.local','OSP Orzechów','UNIT'),
    ('osp.pagow@firemap.local','OSP Pągów','UNIT'),
    ('osp.piaszczyce@firemap.local','OSP Piaszczyce','UNIT'),
    ('osp.plawno@firemap.local','OSP Pławno','UNIT'),
    ('osp.ploszow@firemap.local','OSP Płoszów','UNIT'),
    ('osp.przedborz@firemap.local','OSP Przedbórz','UNIT'),
    ('osp.przybyszow@firemap.local','OSP Przybyszów','UNIT'),
    ('osp.radziechowice.drugie@firemap.local','OSP Radziechowice Drugie','UNIT'),
    ('osp.radziechowice.i@firemap.local','OSP Radziechowice I','UNIT'),
    ('osp.rzejowice@firemap.local','OSP Rzejowice','UNIT'),
    ('osp.silnica@firemap.local','OSP Silnica','UNIT'),
    ('osp.slostowice@firemap.local','OSP Słostowice','UNIT'),
    ('osp.smotryszow@firemap.local','OSP Smotryszów','UNIT'),
    ('osp.sokola.gora@firemap.local','OSP Sokola Góra','UNIT'),
    ('osp.stobiecko.miejskie@firemap.local','OSP Stobiecko Miejskie','UNIT'),
    ('osp.strzalkow@firemap.local','OSP Strzałków','UNIT'),
    ('osp.strzelce.male@firemap.local','OSP Strzelce Małe','UNIT'),
    ('osp.sucha.wies@firemap.local','OSP Sucha Wieś','UNIT'),
    ('osp.szczepocice@firemap.local','OSP Szczepocice','UNIT'),
    ('osp.widawka@firemap.local','OSP Widawka','UNIT'),
    ('osp.wielgomlyny@firemap.local','OSP Wielgomłyny','UNIT'),
    ('osp.wierzbica@firemap.local','OSP Wierzbica','UNIT'),
    ('osp.wojnowice@firemap.local','OSP Wojnowice','UNIT'),
    ('osp.wola.blakowa@firemap.local','OSP Wola Blakowa','UNIT'),
    ('osp.wola.jedlinska@firemap.local','OSP Wola Jedlińska','UNIT'),
    ('osp.wola.malowana@firemap.local','OSP Wola Malowana','UNIT'),
    ('osp.wola.przerebska@firemap.local','OSP Wola Przerębska','UNIT'),
    ('osp.wola.rozkowa@firemap.local','OSP Wola Rożkowa','UNIT'),
    ('osp.wozniki@firemap.local','OSP Woźniki','UNIT'),
    ('osp.zagorze@firemap.local','OSP Zagórze','UNIT'),
    ('osp.zapolice@firemap.local','OSP Zapolice','UNIT'),
    ('osp.zdania@firemap.local','OSP Zdania','UNIT'),
    ('osp.zrabiec@firemap.local','OSP Zrąbiec','UNIT'),
    ('osp.zuzowy@firemap.local','OSP Zuzowy','UNIT'),
    ('osp.zytno@firemap.local','OSP Żytno','UNIT')
), matched as (
  select u.id as user_id, e.unit_name, e.role
  from expected e
  join auth.users u on lower(u.email)=lower(e.email)
)
insert into public.firemap_accounts(user_id,unit_name,role,enabled)
select user_id,unit_name,role,true
from matched
on conflict(user_id) do update set
  unit_name=excluded.unit_name,
  role=excluded.role,
  enabled=true;

-- RAPORT 1: wszystkie poprawnie przypisane konta
select u.email,a.unit_name,a.role,a.enabled
from public.firemap_accounts a
join auth.users u on u.id=a.user_id
where u.email like '%@firemap.local'
order by a.unit_name;

-- RAPORT 2: konta istniejące w Auth, które NIE mają jeszcze wpisu firemap_accounts
select u.email as konto_auth_bez_przypisania
from auth.users u
left join public.firemap_accounts a on a.user_id=u.id
where u.email like '%@firemap.local' and a.user_id is null
order by u.email;
