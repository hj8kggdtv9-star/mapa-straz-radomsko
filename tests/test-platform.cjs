const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const context={Response,crypto:require('crypto').webcrypto};vm.createContext(context);vm.runInContext(fs.readFileSync('manage-platform.js','utf8').replace(/^import .*;\n/,'').replace('export function','function').replace(/Deno.serve[\s\S]*$/,'')+';this.make=makeHandler;',context);
(async()=>{
for(const mode of ['outsider','disabled','admin','create-failure','cleanup-failure']){
 let mutations=0,deleted=0;
 const db={auth:{getUser:async()=>({data:{user:{id:'actor'}}}),admin:{createUser:async()=>{mutations++;return {data:{user:{id:'new'}}}},deleteUser:async()=>{deleted++;return {error:mode==='cleanup-failure'?{}:null}}}},from(table){let insert=false;const q={select(){return q},eq(){return q},order(){return q},range(){return q},insert(){insert=true;mutations++;return q},single:async()=>({data:{slug:'county'}}),maybeSingle:async()=>({data:table==='firemap_platform_admins'?(mode==='outsider'?null:{user_id:'actor'}):mode==='disabled'?{enabled:false}:null}),then(resolve){return resolve(insert?{error:['create-failure','cleanup-failure'].includes(mode)?{}:null}:{data:[]})}};return q;}};
 const h=context.make(()=>db,()=>''),call=body=>h(new Request('https://test.invalid',{method:'POST',headers:{Authorization:'Bearer token'},body:JSON.stringify(body)}));
 if(['outsider','disabled'].includes(mode)){assert.equal((await call({action:'create_admin',name:'Admin',slug:'test'})).status,403);assert.equal(mutations,0)}
 else if(mode==='admin'){assert.equal((await call({action:'list'})).status,200);assert.equal(mutations,0);assert.equal((await call({action:'create_account',role:'ADMIN',name:'test',slug:'test'})).status,400);assert.equal(mutations,0)}
 else{const r=await call({action:'create_account',role:'UNIT',county_id:'county',name:'Test',slug:'test'});assert.equal(r.status,400);assert.equal(deleted,1);const b=await r.json();if(mode==='cleanup-failure')assert.match(b.error,/wycofania/);assert.equal(b.password,undefined)}
}
for(const f of ['admin.js','sk-login-area.js'])new vm.Script(fs.readFileSync(f,'utf8'));
console.log('PASS: only active platform administrators, no mutation for list/invalid roles, provisioning cleanup and failure reporting');
})().catch(e=>{console.error(e);process.exitCode=1});
