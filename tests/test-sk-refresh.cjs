const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const html=fs.readFileSync('dispatcher.html','utf8');
for(const s of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))new vm.Script(s[1]);
(async()=>{
let resolveFirst,calls=0,vehicles=0,subscribed=false;const timers=[],events={};
const ctx={console,Promise,started:false,fetchIncidents:()=>{assert.equal(subscribed,true);calls++;return calls===1?new Promise(r=>resolveFirst=r):Promise.resolve()},refreshVehicles:()=>{vehicles++;return new Promise(()=>{})},document:{hidden:false,addEventListener:(n,f)=>events[n]=f},window:{addEventListener:(n,f)=>events[n]=f},setInterval:(f,ms)=>timers.push({f,ms}),sb:{channel(){const c={on(){return c},subscribe(){subscribed=true;return c}};return c}}};
vm.createContext(ctx);vm.runInContext(html.slice(html.indexOf('let incidentRefreshTask='),html.indexOf('\nasync function accountFor'))+';this.begin=start;this.refresh=refreshIncidents;',ctx);
ctx.begin();assert.equal(calls,1,'incidents start before pending vehicle request finishes');assert.equal(vehicles,1);
const a=ctx.refresh();ctx.refresh();assert.equal(calls,1,'coalesce overlapping requests');resolveFirst();await a;assert.equal(calls,2,'requery after event during in-flight request');
assert.ok(timers.some(t=>t.ms===3000));const before=calls;ctx.document.hidden=true;timers.find(t=>t.ms===3000).f();assert.equal(calls,before,'do not poll hidden tab');ctx.document.hidden=false;events.visibilitychange();await ctx.refresh();assert.ok(calls>before);events.online();await ctx.refresh();
console.log('PASS: incidents independent of slow vehicles, subscribe before fetch, refresh queue, 3s fallback, hidden-tab suppression and reconnect');
})().catch(e=>{console.error(e);process.exitCode=1});
