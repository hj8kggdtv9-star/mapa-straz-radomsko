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
