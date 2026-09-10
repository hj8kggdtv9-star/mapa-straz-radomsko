import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

export function makeHandler(clientFactory, env) {
 const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json'};
 const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers});
 return async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers});
  if(req.method!=='POST')return reply(405,{error:'Użyj POST.'});
  try {
   const token=(req.headers.get('Authorization')||'').replace(/^Bearer\s+/i,'');
   if(!token)return reply(401,{error:'Zaloguj się do SK.'});
   const admin=clientFactory(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
   const {data:userData,error:authError}=await admin.auth.getUser(token);
   if(authError||!userData?.user)return reply(401,{error:'Sesja wygasła. Zaloguj się ponownie.'});
   const {data:account,error:accountError}=await admin.from('firemap_accounts').select('role,enabled,county_id').eq('user_id',userData.user.id).single();
   if(accountError||!account?.enabled||account.role!=='SK'||!account.county_id)return reply(403,{error:'Tylko SK może utworzyć konto sztabu.'});
   const body=await req.json();
   const slug=String(body.slug||'').trim().toLowerCase(),name=String(body.name||'').trim(),password=body.password;
   if(!/^[a-z0-9][a-z0-9-]{2,39}$/.test(slug)||name.length<3||name.length>100||typeof password!=='string'||password.length<12||password.length>128)return reply(400,{error:'Podaj nazwę, identyfikator (3–40 małych liter, cyfr lub myślników) i hasło (12–128 znaków).'});
   const {data:created,error:createError}=await admin.auth.admin.createUser({email:'sztab.'+slug+'@firemap.local',password,email_confirm:true});
   if(createError||!created?.user)return reply(400,{error:'Nie udało się utworzyć konta. Identyfikator może być zajęty lub hasło nie spełnia wymagań.'});
   const {error:profileError}=await admin.from('firemap_accounts').insert({user_id:created.user.id,role:'SZTAB',unit_name:name,enabled:true,county_id:account.county_id,login_email:'sztab.'+slug+'@firemap.local'});
   if(profileError){await admin.auth.admin.deleteUser(created.user.id);return reply(500,{error:'Nie udało się nadać dostępu sztabu. Spróbuj ponownie.'});}
   return reply(201,{slug,name});
  }catch{return reply(500,{error:'Nie udało się utworzyć sztabu. Sprawdź połączenie i spróbuj ponownie.'});}
 };
}
Deno.serve(makeHandler(createClient,key=>Deno.env.get(key)));

