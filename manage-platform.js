import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
export function makeHandler(factory,env){
 const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
 const reply=(status,data)=>new Response(JSON.stringify(data),{status,headers});
 const password=()=> 'Fm!'+Array.from(crypto.getRandomValues(new Uint8Array(18)),x=>x.toString(16).padStart(2,'0')).join('');
 const check=r=>{if(r.error)throw Error('Operacja bazy nie powiodła się. Odśwież listę przed ponowieniem.');return r.data};
 return async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers});
  if(req.method!=='POST')return reply(405,{error:'Użyj POST.'});
  let db,createdUser,createdCounty;
  try{
   db=factory(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
   const token=(req.headers.get('Authorization')||'').replace(/^Bearer\s+/i,'');
   const {data:auth,error}=await db.auth.getUser(token);if(error||!auth?.user)return reply(401,{error:'Zaloguj się ponownie.'});
   const actor=auth.user.id;
   const permission=check(await db.from('firemap_platform_admins').select('user_id').eq('user_id',actor).maybeSingle());
   const profile=check(await db.from('firemap_accounts').select('enabled,archived_at').eq('user_id',actor).maybeSingle());
   if(!permission||(profile&&(!profile.enabled||profile.archived_at)))return reply(403,{error:'Wymagane konto administratora FIREMAP.'});
   const b=await req.json();
   async function all(table,columns){let rows=[];for(let start=0;;start+=500){const page=check(await db.from(table).select(columns).order(table==='firemap_counties'?'id':'user_id').range(start,start+499));rows.push(...page);if(page.length<500)return rows;}}
   if(b.action==='list')return reply(200,{accounts:await all('firemap_accounts','user_id,role,unit_name,login_email,county_id,enabled,archived_at'),counties:await all('firemap_counties','id,slug,name,province'),admins:await all('firemap_platform_admins','user_id')});
   if(['disable','enable','archive','rename','move'].includes(b.action)){
    const result=await db.rpc('firemap_admin_account_change',{p_actor:actor,p_target:b.user_id,p_action:b.action,p_name:b.name||null,p_county:b.county_id||null,p_confirmation:b.confirmation||null});
    if(result.error)return reply(400,{error:result.error.message});return reply(200,{ok:true});
   }
   if(b.action==='reset_password'){
    const target=check(await db.from('firemap_accounts').select('user_id,archived_at').eq('user_id',b.user_id).maybeSingle());
    const protectedAccount=check(await db.from('firemap_platform_admins').select('user_id').eq('user_id',b.user_id).maybeSingle());
    if(!target||target.archived_at||protectedAccount)return reply(400,{error:'Nie można resetować tego konta w tym panelu.'});
    const pass=password();check(await db.auth.admin.updateUserById(target.user_id,{password:pass}));return reply(200,{password:pass});
   }
   if(!['create_account','create_county','create_admin'].includes(b.action))return reply(400,{error:'Nieznana operacja.'});
   const name=String(b.name||'').trim(),slug=String(b.slug||'').trim().toLowerCase();
   if(name.length<3||name.length>100||!(/^[a-z0-9][a-z0-9-]{2,39}$/).test(slug))return reply(400,{error:'Nazwa: 3–100 znaków. Identyfikator: 3–40 małych liter, cyfr lub myślników.'});
   let county=b.county_id,role=b.role,email;
   if(b.action==='create_admin'){
    // A dedicated MATKA identity has no operational profile or county.
    email='admin.'+slug+'@firemap.local';
   }else{
    if(b.action==='create_county'){
     const a=b.area;
     if(!a||typeof a.province!=='string'||typeof a.county!=='string'||a.province.length<2||a.province.length>60||a.county.length<2||a.county.length>100||!Array.isArray(a.bounds)||a.bounds.length!==2||!a.bounds.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite))||a.bounds[0][0]<-85||a.bounds[1][0]>85||a.bounds[0][1]<-180||a.bounds[1][1]>180||a.bounds[0][0]>=a.bounds[1][0]||a.bounds[0][1]>=a.bounds[1][1])return reply(400,{error:'Wybierz województwo i powiat.'});
     const c=check(await db.from('firemap_counties').insert({slug,province:a.province,name:a.county,default_area:a}).select('id').single());county=c.id;createdCounty=county;role='SK';
    }
    if(!['SK','SZTAB','UNIT','JRG'].includes(role))return reply(400,{error:'Nieprawidłowy rodzaj konta.'});
    const c=check(await db.from('firemap_counties').select('slug').eq('id',county).single());
    email=(role==='SZTAB'?'sztab.':role==='SK'?'sk.':'unit.')+c.slug+'.'+slug+'@firemap.local';
   }
   const pass=password();const made=check(await db.auth.admin.createUser({email,password:pass,email_confirm:true}));if(!made?.user)throw Error('Nie utworzono konta.');createdUser=made.user.id;
   if(b.action==='create_admin')check(await db.from('firemap_platform_admins').insert({user_id:createdUser}));
   else check(await db.from('firemap_accounts').insert({user_id:createdUser,role,unit_name:name,county_id:county,login_email:email,enabled:true}));
   return reply(201,{email,password:pass,name});
  }catch(e){
   let cleanupFailed=false;
   if(createdUser){try{if((await db.auth.admin.deleteUser(createdUser)).error)cleanupFailed=true}catch{cleanupFailed=true}}
   if(createdCounty&&!cleanupFailed){try{if((await db.from('firemap_counties').delete().eq('id',createdCounty)).error)cleanupFailed=true}catch{cleanupFailed=true}}
   return reply(400,{error:cleanupFailed?'Tworzenie nie zostało ukończone; nie potwierdzono wycofania zmian. Sprawdź konta przed ponowieniem.':(e.message||'Operacja nie powiodła się.')});
  }
 };
}
Deno.serve(makeHandler(createClient,key=>Deno.env.get(key)));
