const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=process.env.FIREMAP_TEST_ROOT||path.join(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
async function edgeTests(){
 const src=read('manage-county.js').replace(/^import .*;\n/m,'').replace('export function','function').replace(/Deno.serve[\s\S]*$/,'');
 const ctx={Response,crypto:require('node:crypto').webcrypto};vm.createContext(ctx);vm.runInContext(src+';this.make=makeHandler;',ctx);
 let role='SK',enabled=true,platform=false,targetCounty='own',created=0,reset=0,profile,countyInput,failProfile=false,deleted=0;
 const admin={auth:{getUser:async()=>({data:{user:{id:'sk'}}}),admin:{createUser:async b=>(created++,{data:{user:{id:'new'}}}),updateUserById:async()=>{reset++;return{}},deleteUser:async()=>{deleted++}}},from:table=>{let value,filter;return {select(){return this},eq(k,v){filter=v;return this},insert(v){value=v;if(table==='firemap_accounts'){profile=v;return Promise.resolve({error:failProfile?{}:null});}countyInput=v;return this},delete(){return this},async single(){if(table==='firemap_counties')return{data:value?{id:'new-county'}:{slug:'own-county'}};return{data:filter==='sk'?{role,enabled,county_id:'own'}:{user_id:'unit',role:'UNIT',county_id:targetCounty}}},async maybeSingle(){return{data:platform?{user_id:'sk'}:null}}}}};
 const fn=ctx.make(()=>admin,()=>''),call=(body,token='token')=>fn(new Request('https://example.invalid',{method:'POST',headers:token?{Authorization:'Bearer '+token}:{},body:JSON.stringify(body)}));
 const unit={action:'create_unit',name:'OSP Test',slug:'osp-test',county_id:'foreign',role:'UNIT'};
 assert.equal((await call(unit,'')).status,401);
 role='UNIT';assert.equal((await call(unit)).status,403);role='SZTAB';assert.equal((await call(unit)).status,403);role='SK';enabled=false;assert.equal((await call(unit)).status,403);enabled=true;
 assert.equal((await call({...unit,role:'SK'})).status,400);assert.equal(created,0);
 let r=await call(unit);assert.equal(r.status,201);let d=await r.json();assert.equal(profile.county_id,'own');assert.equal(profile.role,'UNIT');assert.equal(profile.login_email,'unit.own-county.osp-test@firemap.local');assert.ok(d.password.length>=20);
 targetCounty='foreign';assert.equal((await call({action:'reset_password',user_id:'unit'})).status,403);assert.equal(reset,0);targetCounty='own';assert.equal((await call({action:'reset_password',user_id:'unit'})).status,200);assert.equal(reset,1);
 const county={action:'create_county',name:'SK Test',slug:'test-county',area:{province:'TEST',county:'TEST',bounds:[[51,19],[52,20]]}};
 assert.equal((await call(county)).status,403);platform=true;assert.equal((await call(county)).status,201);assert.equal(profile.county_id,'new-county');assert.equal(profile.role,'SK');
 failProfile=true;assert.equal((await call(unit)).status,400);assert.equal(deleted,1);
}
function routeChecks(){
 assert.match(read('login.html'),/county-login\.js/);
 assert.match(read('county-login.js'),/firemap_county_logins/);
 assert.match(read('dispatcher.html'),/a\.county_id!==\$\('skCountyLogin'\)\.value/);
 assert.match(read('vehicle.html'),/\.eq\('account_id',session\.user\.id\)/);
 assert.match(read('vehicle.html'),/\[\[-85,-180\],\[85,180\]\]/);
 assert.match(read('external-join.html'),/value="LOCAL"/);
 assert.match(read('external-forces-vehicle.js'),/if\(!window\.firemapGlobalVehiclePublisher\)/);
}
(async()=>{await edgeTests();routeChecks();console.log('PASS: SK-only provisioning, county-bound unit creation, no privilege escalation, own-unit password reset, platform-only activation, cleanup and client integration');})().catch(e=>{console.error(e);process.exitCode=1});
