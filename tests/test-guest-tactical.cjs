const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
(async()=>{
 const ctx={window:{},document:{},console};vm.createContext(ctx);vm.runInContext(fs.readFileSync('guest-tactical.js','utf8'),ctx);
 let calls=[],expired=0,fail=false;const sb={rpc:async(name,args)=>{calls.push({name,args});return fail?{error:{message:'Sesja wygasła'}}:{data:name==='external_tactical_read'?{incident:{id:'own',active:true},drawings:[{id:'a',incident_id:'own',created_by:'session'},{id:'b',incident_id:'other-same-hq',created_by:'another-session'}]}:true};}};
 const a=ctx.window.firemapGuestTacticalAdapter(sb,{session_token:'opaque-token'},()=>expired++);
 let r=await a.from('incidents').select('id').eq('active',true).order('created_at');assert.equal(r.data[0].id,'own');
 r=await a.from('incident_drawings').select('*').eq('incident_id','own').order('created_at');assert.equal(r.data.length,1);
 r=await a.from('incident_drawings').select('*').in('incident_id',['own']).order('created_at');assert.equal(r.data.length,2,'shared viewer includes other active incidents in this HQ');
 r=await a.from('incident_drawings').upsert([{id:'a'}]);assert.equal(r.error,null);assert.equal(calls.at(-1).name,'external_tactical_write');assert.equal(calls.at(-1).args.p_session_token,'opaque-token');
 r=await a.from('incident_drawings').delete().eq('incident_id','own').eq('created_by','session').in('id',['a']);assert.deepEqual(calls.at(-1).args.p_delete_ids,['a']);
 fail=true;r=await a.from('incident_drawings').upsert([{id:'a'}]);assert.ok(r.error,'failed publication must preserve editor draft');
 r=await a.from('incidents').select('*');assert.ok(r.error);assert.equal(expired,1);
 for(const f of ['guest-tactical.js','rapid-hq.js','hq-login-directory.js','sk-join-codes.js','tactical-ui-core.js','tactical-shared-viewer.js','external-join.js','sztab-admin.js'])new vm.Script(fs.readFileSync(f,'utf8'),{filename:f});
 console.log('PASS: guest adapter reads HQ tactics, scopes writes to RPC token, preserves errors and expires sessions; changed JS parses');
})().catch(e=>{console.error(e);process.exitCode=1});

// Tool mounting must not disappear when the initial RPC is unavailable.
(async()=>{
 const loaded=[],notice={hidden:true},window={};let failedOnce=false;
 const document={getElementById:()=>notice,createElement:()=>({remove(){}}),head:{appendChild(el){loaded.push(el.src);queueMicrotask(()=>{if(el.src.startsWith('forest-map-layers')&&!failedOnce){failedOnce=true;el.onerror()}else el.onload()})}}};
 const ctx={window,document,console};vm.createContext(ctx);vm.runInContext(fs.readFileSync('guest-tactical.js','utf8'),ctx);
 const args={map:{},sb:{rpc(){throw Error('Offline')}},state:{session_id:'session',session_token:'token'},onExpired(){}};
 await window.startFiremapGuestTactical(args);
 assert.ok(loaded.some(x=>x.startsWith('tactical-ui-core')),'editor loads independently of failed layers and RPC');
 assert.match(notice.textContent,/ponowić/);assert.equal(window.firemapGuestTacticalStarted,undefined);
 await notice.onclick();assert.equal(window.firemapGuestTacticalStarted,true);assert.equal(notice.hidden,true);
 assert.equal(loaded.filter(x=>x.startsWith('tactical-ui-core')).length,1,'retry must not duplicate editor');
 assert.equal(loaded.filter(x=>x.startsWith('forest-map-layers')).length,2,'failed layer script retries');
 console.log('PASS: QR tools mount without RPC, report script failure and retry without duplicate editor');
})().catch(e=>{console.error(e);process.exitCode=1});
