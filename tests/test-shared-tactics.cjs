const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
(async()=>{
const live=new Set(),rows=[{id:'water',incident_id:'i',created_by:'kdr-other',category:'WATER',geometry_type:'POLYLINE',geometry:{points:[[51,19],[51.01,19.01]]},label:'Woda'}];
let refresh;const layer=()=>({addTo(){live.add(this);return this},bindPopup(){return this},bindTooltip(){return this}});
const map={removeLayer:l=>live.delete(l),hasLayer:l=>live.has(l)};
const sb={from:table=>{const q={select(){return q},eq(){return q},in(){return q},order(){return q},then(resolve){resolve({data:table==='incidents'?[{id:'i'}]:rows})}};return q},channel(){return{on(){return this},subscribe(){}}}};
const window={firemapCtx:{map,sb,session:{user:{id:'self'}}},firemapTacticalEditor:{localVisible:true,incidentId:'i'},addEventListener(){}};
vm.runInNewContext(fs.readFileSync('tactical-shared-viewer.js','utf8'),{window,document:{addEventListener(){}},L:{polyline:layer,polygon:layer,circle:layer},setInterval:f=>refresh=f,setTimeout,Map,Set,console});
await new Promise(setImmediate);assert.equal(live.size,1,'other KDR water stays visible while own editor is active');
rows.length=0;await refresh();assert.equal(live.size,0,'removed publication disappears');
console.log('PASS: shared water visible alongside local KDR editor; deletion synchronized');
})();
