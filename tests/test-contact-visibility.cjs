const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
(async()=>{
const source=fs.readFileSync('vehicle.html','utf8');
const rows=[{id:'other',unit_name:'OSP Test',call_sign:'TEST-1',vehicle_type:'GBA',status:'ON_SCENE',lat:51,lng:19,updated_at:new Date().toISOString(),contact_phone:'+48600123456'}];
const list={innerHTML:''},popups=[];
const marker={addTo(){return this},bindPopup(s){popups.push(s)},setLatLng(){},setIcon(){}};
const ctx={window:{},Date,Map,Set,Number,Math,console,sb:{from:()=>({select:()=>({order:async()=>({data:rows})})})},$:()=>list,BOUNDS:{contains:()=>true},ACTIVE_VEHICLE_MS:180000,myId:'self',kdrId:'self-kdr',myData:null,markers:new Map(),map:{removeLayer(){}},L:{marker:()=>marker},vIcon:()=>null,isKdr:()=>false,vehicleKey:v=>v.id,STATUS:{BASE:{label:'Baza'},ON_SCENE:{label:'Na miejscu'}},esc:s=>s};
vm.createContext(ctx);vm.runInContext(fs.readFileSync('terminal-contact.js','utf8'),ctx);
const start=source.indexOf('async function refreshVehicles()'),end=source.indexOf('async function refreshIncidents()',start);
vm.runInContext(source.slice(start,end),ctx);await ctx.refreshVehicles();
assert.match(list.innerHTML,/href="tel:\+48600123456"/);assert.match(popups[0],/href="tel:\+48600123456"/);
rows[0].contact_phone=null;await ctx.refreshVehicles();assert.doesNotMatch(list.innerHTML,/href="tel:/);assert.match(list.innerHTML,/Brak udostępnionego telefonu/);
rows.length=0;await ctx.refreshVehicles();assert.match(list.innerHTML,/Brak innych aktywnych/);
for(const file of ['incident-assignment-sk.js','external-forces-sk.js']){const s=fs.readFileSync(file,'utf8');new vm.Script(s);assert.match(s,/closest\('a'\)/);assert.match(s,/firemapContact.popup\(v.contact_phone\)/)}
const guest=fs.readFileSync('external-join.js','utf8');assert.match(guest,/<\/button>\$\{window.firemapContact.popup\(v.contact_phone\)\}<\/div>/);
console.log('PASS: terminal renders phone in contacts and popup, removes cleared phone, handles empty peers; SK call links bypass map click; QR links outside buttons');
})();
