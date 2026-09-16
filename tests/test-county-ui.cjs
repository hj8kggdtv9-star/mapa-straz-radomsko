const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=process.env.FIREMAP_TEST_ROOT||path.join(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
async function edgeTests(){
 for(const file of ['manage-county.js','create-sztab.js']){
  const ctx={Response};vm.createContext(ctx);vm.runInContext(read(file).replace('export function','function').replace(/Deno.serve[\s\S]*$/,'')+';this.make=makeHandler;',ctx);
  const fn=ctx.make(()=>{throw Error('Retired endpoint must not access database')});
  for(const action of ['create_unit','create_county','reset_password','create_sztab']){
   const r=await fn(new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer old-session'},body:JSON.stringify({action})}));
   assert.equal(r.status,410);assert.equal((await r.json()).code,'USE_MATKA');
  }
 }
 assert.doesNotMatch(read('tactical-viewer.js'),/load\('(county-admin|sztab-admin)\.js'\)/);
 assert.match(read('tactical-viewer.js'),/load\('sk-join-codes.js'\)/);
 assert.match(read('admin.js'),/manage-platform/);
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
(async()=>{await edgeTests();routeChecks();console.log('PASS: retired SK endpoints deny all mutations, SK retains QR, MATKA entrypoint and county routing retained');})().catch(e=>{console.error(e);process.exitCode=1});
