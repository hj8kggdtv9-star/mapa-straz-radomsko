const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.join(__dirname,'..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
async function provisioning(){
 for(const file of ['manage-county.js','create-sztab.js']){
  for(const profileFailure of ['returned','thrown'])for(const cleanupFailure of ['none','returned','thrown']){
   let deleted=0,countyDeleted=0,logs=[];
   const admin={auth:{getUser:async()=>({data:{user:{id:'operator'}}}),admin:{createUser:async()=>({data:{user:{id:'new-user'}}}),deleteUser:async()=>{deleted++;if(cleanupFailure==='thrown')throw Error('offline');return {error:cleanupFailure==='returned'?Error('delete failed'):null};}}},from:table=>{
    let inserting=false,deleting=false;
    const q={select(){return q},eq(){return q},insert(){inserting=true;return q},delete(){deleting=true;return q},async single(){return table==='firemap_counties'?{data:{id:'new-county',slug:'test'}}:{data:{role:'SK',enabled:true,county_id:'own'}}},async maybeSingle(){return {data:{user_id:'operator'}}},then(resolve,reject){return Promise.resolve().then(()=>{if(deleting){countyDeleted++;return {error:null}}if(inserting&&table==='firemap_accounts'){if(profileFailure==='thrown')throw Error('timeout');return {error:Error('profile failed')}}return {error:null};}).then(resolve,reject)}};return q;
   }};
   const ctx={Response,console:{error:(...x)=>logs.push(x)},crypto:require('node:crypto').webcrypto};vm.createContext(ctx);
   vm.runInContext(read(file).replace(/^import .*;\n/m,'').replace('export function','function').replace(/Deno.serve[\s\S]*$/,'')+';this.make=makeHandler;',ctx);
   const handler=ctx.make(()=>admin,()=>''),body={action:'create_county',slug:'test-county',name:'Test HQ',password:'Test-password-123!',area:{province:'TEST',county:'TEST',bounds:[[51,19],[52,20]]}};
   const response=await handler(new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer test'},body:JSON.stringify(body)}));
   const payload=await response.json();assert.equal(deleted,1,file+' must clean up on both kinds of profile failure');assert.equal(response.headers.get('Cache-Control'),'no-store');
   if(cleanupFailure!=='none'){assert.equal(response.status,500);assert.equal(payload.code,'PROVISIONING_CLEANUP_REQUIRED');assert.equal(logs.length,1);assert.ok(!JSON.stringify(logs).includes(body.password));assert.equal(countyDeleted,0,'keep county on uncertain user deletion');}
   else{assert.equal(payload.code,undefined);assert.equal(countyDeleted,file==='manage-county.js'?1:0);}
  }
 }
}
async function vehicle(){
 const html=read('vehicle.html');for(const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))new vm.Script(m[1]);
 const elements=new Map(),storage=new Map(),messages=[],buttons=[{dataset:{status:'BASE'}}];let response={data:[],error:null};
 const ctx={console:{error(){}},Promise,Date,Error,Array,localStorage:{setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},$:id=>{if(!elements.has(id))elements.set(id,{style:{}});return elements.get(id)},toast:m=>messages.push(m),vehicleLabel:()=>'',verifiedUnit:'OSP Test',document:{querySelectorAll:()=>buttons},myData:{call:'TEST',type:'GBA'},myId:'vehicle',kdrId:'kdr',kdrMode:false,parkedVehiclePos:null,currentStatus:'ON_SCENE',connected:true,STATUS:{BASE:{label:'W bazie'}},statusUI(){},closeSheet(){},forceGpsFix(){},refreshVehicles(){},openVehicleSettings(){},ensureGps(){},sb:{from:()=>({update:()=>({in:()=>({select:async()=>response})})})}};
 vm.createContext(ctx);
 const helper=html.slice(html.indexOf('let vehicleWriteTail='),html.indexOf('async function publishPosition('));
 const handler=html.slice(html.indexOf("document.querySelectorAll('[data-status]').forEach(b=>b.onclick=async()=>"),html.indexOf("\n$('statusBtn').onclick="));
 vm.runInContext(helper+'\n'+handler+'\nthis.queue=queueVehicleWrite;this.checked=checkedVehicleWrite;',ctx);
 // Permission denial, zero rows and network exception must not report or store success.
 for(const failure of [{data:null,error:Error('RLS')},{data:[],error:null}]){
  response=failure;await buttons[0].onclick();assert.equal(ctx.currentStatus,'ON_SCENE');assert.equal(storage.has('firemapStatus'),false);assert.ok(!messages.some(m=>m.startsWith('Status zapisany')));assert.equal(buttons[0].disabled,false);
 }
 await assert.rejects(ctx.checked({select:async()=>{throw Error('offline')}},['vehicle']),/offline/);
 response={data:[{id:'vehicle'}],error:null};await buttons[0].onclick();assert.equal(ctx.currentStatus,'BASE');assert.equal(storage.get('firemapStatus'),'BASE');assert.ok(messages.some(m=>m.startsWith('Status zapisany')));
 // A KDR BASE change must confirm both rows before clearing local KDR state.
 ctx.currentStatus='ON_SCENE';ctx.kdrMode=true;ctx.parkedVehiclePos=[51,19];response={data:[{id:'vehicle'}],error:null};await buttons[0].onclick();assert.equal(ctx.kdrMode,true);assert.equal(ctx.currentStatus,'ON_SCENE');
 response={data:[{id:'vehicle'},{id:'kdr'}],error:null};await buttons[0].onclick();assert.equal(ctx.kdrMode,false);assert.equal(ctx.currentStatus,'BASE');
 // A failed write must not poison the queue or allow later writes to overtake it.
 let release,order=[];const first=ctx.queue(async()=>{order.push('gps');await new Promise(r=>release=r);throw Error('offline')});const second=ctx.queue(async()=>order.push('status'));
 await Promise.resolve();assert.deepEqual(order,['gps']);release();await assert.rejects(first,/offline/);await second;assert.deepEqual(order,['gps','status']);
}
(async()=>{await provisioning();await vehicle();console.log('PASS: returned/thrown provisioning failures, cleanup failure reporting, no secret logging, status acknowledgement, zero-row denial, KDR acknowledgement and serialized writes');})().catch(e=>{console.error(e);process.exitCode=1});
