import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
export function makeHandler(factory,env){
 const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json'};
 const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers});
 return async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers});
  if(req.method!=='POST')return reply(405,{error:'Użyj POST.'});
  let admin,createdUser,createdCounty;
  try{
   const token=(req.headers.get('Authorization')||'').replace(/^Bearer\s+/i,'');
   if(!token)return reply(401,{error:'Zaloguj się do SK.'});
   admin=factory(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
   const {data:u,error:ue}=await admin.auth.getUser(token);
   if(ue||!u?.user)return reply(401,{error:'Sesja wygasła.'});
   const {data:a,error:ae}=await admin.from('firemap_accounts').select('role,enabled,county_id').eq('user_id',u.user.id).single();
   if(ae||!a?.enabled||a.role!=='SK'||!a.county_id)return reply(403,{error:'Wymagane aktywne konto SK powiatu.'});
   const b=await req.json(),slug=String(b.slug||'').trim().toLowerCase(),name=String(b.name||'').trim();
   if(!['create_county','create_unit','reset_password'].includes(b.action))return reply(400,{error:'Nieznana operacja.'});
   let password=b.password;
   if(!password){const bytes=crypto.getRandomValues(new Uint8Array(24));password='Fm!'+Array.from(bytes,x=>x.toString(16).padStart(2,'0')).join('');}
   if(typeof password!=='string'||password.length<12||password.length>128)return reply(400,{error:'Hasło musi mieć 12–128 znaków.'});
   if(b.action==='reset_password'){
    const {data:target}=await admin.from('firemap_accounts').select('user_id,role,county_id').eq('user_id',b.user_id).single();
    if(!target||target.county_id!==a.county_id||!['UNIT','JRG'].includes(target.role))return reply(403,{error:'Możesz zmieniać hasła tylko własnych jednostek.'});
    const {error}=await admin.auth.admin.updateUserById(target.user_id,{password});if(error)throw Error('Nie udało się zmienić hasła.');
    return reply(200,{password});
   }
   if(!/^[a-z0-9][a-z0-9-]{2,59}$/.test(slug)||name.length<3||name.length>100)return reply(400,{error:'Podaj nazwę i identyfikator (3–60 małych liter, cyfr lub myślników).'});
   let countyId=a.county_id,role='UNIT',email;
   if(b.action==='create_county'){
    const {data:permission}=await admin.from('firemap_platform_admins').select('user_id').eq('user_id',u.user.id).maybeSingle();
    if(!permission)return reply(403,{error:'Tylko administrator FIREMAP może aktywować kolejne powiaty.'});
    const area=b.area;
    if(!area||typeof area.province!=='string'||typeof area.county!=='string'||area.province.length>60||area.county.length>100||!Array.isArray(area.bounds)||area.bounds.length!==2||!area.bounds.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite))||area.bounds[0][0]<-85||area.bounds[1][0]>85||area.bounds[0][1]<-180||area.bounds[1][1]>180||area.bounds[0][0]>=area.bounds[1][0]||area.bounds[0][1]>=area.bounds[1][1])return reply(400,{error:'Wybierz województwo i powiat z listy.'});
    const {data:c,error:ce}=await admin.from('firemap_counties').insert({slug,province:area.province,name:area.county,default_area:area}).select('id').single();
    if(ce)throw Error('Powiat lub identyfikator jest już zarejestrowany.');
    createdCounty=c.id;countyId=c.id;role='SK';email='sk.'+slug+'@firemap.local';
   }else{
    if(!['UNIT','JRG'].includes(b.role||'UNIT'))return reply(400,{error:'Wybierz jednostkę OSP lub JRG.'});
    role=b.role||'UNIT';
    const {data:c,error:ce}=await admin.from('firemap_counties').select('slug').eq('id',a.county_id).single();
    if(ce||!c)throw Error('Brak powiatu konta SK.');
    email='unit.'+c.slug+'.'+slug+'@firemap.local';
   }
   const {data:made,error:me}=await admin.auth.admin.createUser({email,password,email_confirm:true});
   if(me||!made?.user)throw Error('Nie udało się utworzyć konta. Identyfikator może być zajęty.');
   createdUser=made.user.id;
   const {error:pe}=await admin.from('firemap_accounts').insert({user_id:createdUser,role,unit_name:name,enabled:true,county_id:countyId,login_email:email});
   if(pe)throw Error('Nie udało się przypisać konta do powiatu.');
   return reply(201,{name,role,email,password,county_id:countyId});
  }catch(e){
   if(createdUser)await admin.auth.admin.deleteUser(createdUser);
   if(createdCounty)await admin.from('firemap_counties').delete().eq('id',createdCounty);
   return reply(400,{error:e instanceof Error?e.message:'Operacja nie powiodła się.'});
  }
 };
}
Deno.serve(makeHandler(createClient,key=>Deno.env.get(key)));
