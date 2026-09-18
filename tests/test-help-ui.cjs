const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
(async()=>{
const els=new Map(),timers=new Map();let seq=0,calls=[];
class El{constructor(){this.events={};this.dataset={};this.style={};this.value='';this.hidden=false}set id(v){this._id=v;els.set(v,this)}get id(){return this._id}setAttribute(){}addEventListener(n,f){this.events[n]=f}querySelector(s){const id=s.slice(1);if(!els.has(id)){const e=new El();e.id=id}return els.get(id)}querySelectorAll(){return []}}
const sb={from:()=>({select(){return this},eq:async()=>({data:[{id:'i',description:'TEST'}]})}),rpc:async(n,args)=>{calls.push(n);return{data:n==='firemap_help_read'?[]:'id',error:null}}};
const navigator={onLine:true},ctx={window:{firemapCtx:{sb,map:{}},addEventListener(){}},document:{createElement:()=>new El(),body:{appendChild(){}},head:{appendChild(){}},addEventListener(){}},navigator,localStorage:{getItem:()=> 'i'},setInterval(){},setTimeout:(f)=>{timers.set(++seq,f);return seq},clearTimeout:id=>timers.delete(id),confirm:()=>true,console};
vm.runInNewContext(fs.readFileSync('incident-help.js','utf8'),ctx);await new Promise(setImmediate);calls=[];
const b=els.get('fmHelpButton'),send=()=>els.get('helpSend').onclick();
b.events.pointerdown({button:0});b.events.pointerup();await send();assert.equal(calls.length,0,'short press and unarmed confirmation cannot send');
b.events.pointerdown({button:0});[...timers.values()].forEach(f=>f());await new Promise(setImmediate);assert.equal(calls.length,0,'hold alone cannot send');
navigator.onLine=false;await send();assert.equal(calls.length,0,'offline confirmation never sends or queues');assert.match(els.get('helpStatus').textContent,/NIE ZOSTAŁA WYSŁANA/);
navigator.onLine=true;await send();assert.equal(calls.filter(n=>n==='firemap_help_raise').length,1);await send();assert.equal(calls.filter(n=>n==='firemap_help_raise').length,1,'acknowledged send disarms');
console.log('PASS: short tap, hold-only and offline do not send HELP; explicit confirmation sends once');
})();
