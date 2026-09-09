const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=process.env.FIREMAP_TEST_ROOT||path.join(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8'),tick=()=>new Promise(r=>setImmediate(r));
async function edgeTests(){
 const source=read('create-sztab.js').replace(/^import .*;\n/m,'').replace('export function makeHandler','function makeHandler').replace(/Deno.serve[\s\S]*$/,'');
 const ctx={Response};vm.createContext(ctx);vm.runInContext(source+';this.factory=makeHandler;',ctx);
 let role='SK',enabled=true,valid=true,created=0,deleted=0,profileError=false,last;
 const admin={auth:{getUser:async()=>({data:{user:valid?{id:'operator'}:null}}),admin:{createUser:async body=>(created++,last=body,{data:{user:{id:'new'}}}),deleteUser:async()=>{deleted++}}},from:()=>({select(){return this},eq(){return this},single:async()=>({data:{role,enabled}}),insert:async body=>{assert.equal(body.role,'SZTAB');return {error:profileError?{}:null}}})};
 const handler=ctx.factory(()=>admin,()=>''),call=(token='token',body={slug:'las-2026',name:'Sztab Las',password:'Test-password-123'})=>handler(new Request('https://example.invalid',{method:'POST',headers:token?{Authorization:'Bearer '+token}:{},body:JSON.stringify(body)}));
 assert.equal((await call('')).status,401);valid=false;assert.equal((await call()).status,401);valid=true;
 for(role of ['UNIT','SZTAB'])assert.equal((await call()).status,403);
 role='SK';enabled=false;assert.equal((await call()).status,403);enabled=true;
 assert.equal((await call('token',{slug:'bad@id',name:'Test',password:'short'})).status,400);assert.equal(created,0);
 const res=await call();assert.equal(res.status,201);assert.equal(last.email,'sztab.las-2026@firemap.local');assert.equal(last.email_confirm,true);assert.ok(!(await res.text()).includes('password'));
 profileError=true;assert.equal((await call()).status,500);assert.equal(deleted,1);
}
async function loginTest(role,slug,expect){
 const nodes=new Map(),routes=[];let signedOut=0,credentials;
 const node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',innerHTML:'',addEventListener(){}});return nodes.get(id)};
 const account={role,enabled:true,unit_name:role==='SZTAB'?'Sztab Las':'OSP Test'};
 const sb={auth:{getSession:async()=>({data:{session:null}}),signOut:async()=>{signedOut++},signInWithPassword:async p=>(credentials=p,{data:{user:{id:'u'}}})},from:()=>({select(){return this},eq(){return this},maybeSingle:async()=>({data:account})})};
 const ctx={document:{getElementById:node},supabase:{createClient:()=>sb},L:{map:()=>({setView(){return this}}),tileLayer:()=>({addTo(){}})},fetch:async()=>({json:async()=>({units:[{slug:'osp-test',name:'OSP Test'}]})}),localStorage:{setItem(){},getItem:()=>null},location:{replace:p=>routes.push(p)},setTimeout:f=>f()};
 vm.runInNewContext(read('login.html').match(/<script>\s*([\s\S]*?)<\/script>/)[1],ctx);await tick();
 assert.match(node('unit').innerHTML,/SZTAB/);node('unit').value=slug;node('sztabLoginId').value='las-2026';node('password').value='test-password';
 node('unit').onchange();assert.equal(node('sztabLoginFields').hidden,slug!=='sztab');
 await node('loginBtn').onclick();await tick();assert.deepEqual(routes,expect?[expect]:[]);
 if(slug==='sztab')assert.equal(credentials.email,'sztab.las-2026@firemap.local');
}
async function dispatcherTests(){
 const source=read('dispatcher.html'),auth=source.slice(source.indexOf('async function accountFor'),source.indexOf("$('logout').onclick"));
 const nodes=new Map();const node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',style:{}});return nodes.get(id)};let role='SZTAB',starts=0,signouts=0;
 const sb={auth:{getSession:async()=>({data:{session:{user:{id:'hq'}}}}),signInWithPassword:async()=>({data:{session:{user:{id:'hq'}}}}),signOut:async()=>{signouts++}},from:()=>({select(){return this},eq(){return this},maybeSingle:async()=>({data:{role,enabled:true,unit_name:'Las'}})})};
 const ctx={sb,$:node,window:{firemapSkCtx:{}},document:{querySelector:()=>node('sub')},history:{replaceState(){}},location:{search:'?chooseArea=1',pathname:'/dispatcher.html'},URLSearchParams,EMAIL:'sk@firemap.local',start:()=>{starts++}};
 vm.createContext(ctx);vm.runInContext(auth,ctx);await vm.runInContext('logged()',ctx);
 assert.equal(starts,0);assert.equal(node('password').hidden,true);assert.equal(node('loginBtn').textContent,'Otwórz panel');
 await node('loginBtn').onclick();assert.equal(starts,1);assert.equal(node('sub').textContent,'SZTAB — Las');
 role='UNIT';await vm.runInContext('logged()',ctx);assert.equal(signouts,1);
}
(async()=>{await edgeTests();await loginTest('SZTAB','sztab','./dispatcher.html?chooseArea=1');await loginTest('UNIT','osp-test','./index.html');await loginTest('UNIT','sztab',null);await dispatcherTests();console.log('PASS: provisioning authorization, validation, cleanup; SZTAB and OSP login, role mismatch, area selection and panel authorization');})().catch(e=>{console.error(e);process.exitCode=1});
