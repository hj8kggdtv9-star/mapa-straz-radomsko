// Retired SK account-management endpoint. MATKA uses manage-platform.
export function makeHandler(){
 const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
 return async req=>req.method==='OPTIONS'?new Response('ok',{headers}):new Response(JSON.stringify({error:'Zarządzanie kontami przeniesiono do panelu MATKA.',code:'USE_MATKA'}),{status:410,headers});
}
Deno.serve(makeHandler());
