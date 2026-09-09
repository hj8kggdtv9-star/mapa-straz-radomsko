const vm=require('node:vm'),fs=require('node:fs'),assert=require('node:assert/strict');
const code=fs.readFileSync('external-join.js','utf8'),tick=()=>new Promise(r=>setImmediate(r));
const db=new Map();let incidentActive=true,network=false;
function terminal(id){
 const nodes=new Map(),buttons=['DISPATCHED','ON_SCENE','RETURNING','BASE'].map(s=>({dataset:{s},classList:{toggle(){}}})),intervals=[],events={},layers=new Set();let gps;
 const node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',innerHTML:'',textContent:'',style:{},querySelectorAll:()=>[]});return nodes.get(id)};
 let stored=JSON.stringify({session_token:id,vehicle_id:id,call_sign:'QR-'+id,origin_unit:'TEST '+id,origin_county:'TEST',force_group:'WOO',incident_lat:52,incident_lng:21});
 const map={setView(){return this},invalidateSize(){},removeLayer:l=>layers.delete(l),fitBounds(){},flyTo(){}};
 const marker=(ll,opts={})=>({ll,opts,addTo(){layers.add(this);return this},bindTooltip(s){this.tooltip=s;return this},bindPopup(s){this.popup=s;return this},setLatLng(ll){this.ll=ll;return this},setIcon(icon){this.opts.icon=icon;return this},getLatLng(){return this.ll},openPopup(){}});
 const ctx={URLSearchParams,location:{search:'',pathname:'/external-join.html'},document:{hidden:false,getElementById:node,querySelectorAll:()=>buttons,addEventListener:(n,f)=>events[n]=f},window:{addEventListener:(n,f)=>events[n]=f},localStorage:{getItem:()=>stored,setItem:(k,v)=>stored=v,removeItem:()=>stored=null},navigator:{geolocation:{watchPosition:f=>(gps=f,1),clearWatch(){}}},L:{map:()=>map,tileLayer:()=>({addTo(){}}),marker,divIcon:x=>x,latLngBounds:x=>x},supabase:{createClient:()=>({rpc:async(name,p)=>{
 if(network)return {error:{message:'Failed to fetch'}};
 if(!incidentActive)return {error:{code:'P0001',message:'Sesja wygasła'}};
 if(name==='external_force_update'){db.set(id,{id,call_sign:'QR-'+id,unit_name:'TEST '+id,vehicle_type:'GBA',status:p.p_status,lat:p.p_lat,lng:p.p_lng,updated_at:new Date().toISOString(),force_group:'WOO'});return {data:true}}
 if(name==='external_force_peers')return {data:[...db.values()].filter(v=>v.id!==p.p_session_token)};
 if(name==='external_force_leave'){db.delete(id);return {data:true}}
 throw Error('Unexpected RPC '+name);
 }})},setTimeout(){},setInterval:f=>(intervals.push(f),intervals.length),clearInterval(){},confirm:()=>true};
 vm.runInNewContext(code,ctx);
 return {node,buttons,layers,events,intervals,get saved(){return stored},gps:()=>gps({coords:{latitude:52,longitude:21,accuracy:5,speed:null,heading:null}}),poll:()=>intervals.forEach(f=>f())};
}
(async()=>{
 const a=terminal('A'),b=terminal('B');a.gps();b.gps();await tick();a.poll();b.poll();await tick();
 assert.ok([...a.layers].some(m=>m.tooltip==='QR-B'));assert.ok([...b.layers].some(m=>m.tooltip==='QR-A'));
 assert.equal(a.node('peersState').textContent,'Inne zastępy w zdarzeniu: 1');
 b.buttons[1].onclick();await tick();a.poll();await tick();assert.match([...a.layers].find(m=>m.tooltip==='QR-B').opts.icon.html,/#dc2626/);
 b.buttons[2].onclick();await tick();a.poll();await tick();assert.match([...a.layers].find(m=>m.tooltip==='QR-B').popup,/KONIEC/);
 network=true;a.poll();await tick();assert.ok([...a.layers].some(m=>m.tooltip==='QR-B'));assert.match(a.node('peersState').textContent,/nieaktualny/);network=false;
 b.buttons[3].onclick();await tick();a.poll();await tick();assert.ok(![...a.layers].some(m=>m.tooltip==='QR-B'));assert.equal(a.node('peersState').textContent,'Inne zastępy w zdarzeniu: 0');
 incidentActive=false;a.poll();await tick();assert.equal(a.saved,null);
 console.log('PASS: two independent QR clients see each other at identical GPS coordinates; status colors, status changes, connection error, leaving peer removal, session expiry');
})().catch(e=>{console.error(e);process.exitCode=1});
