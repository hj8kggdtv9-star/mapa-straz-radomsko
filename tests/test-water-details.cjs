const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
async function run(contextName){
const live=new Set();let shown;
class Line{constructor(p,o={}){this.p=p;this.options=o;this.events={}}getLatLngs(){return this.p}on(n,f){this.events[n]=f;return this}addTo(){live.add(this);return this}unbindPopup(){this.unbound=true}fire(n,e){this.events[n]?.(e)}}
class Polygon extends Line{}
const water=new Line([{lat:51,lng:19},{lat:51.1,lng:19},{lat:51.2,lng:19}],{color:'#123456',weight:3});water._firemapCategory='WATER';live.add(water);
const map={eachLayer:f=>[...live].forEach(f),on(){},hasLayer:l=>live.has(l),removeLayer:l=>live.delete(l),distance:()=>25};
const el=()=>({classList:{add(){},remove(){}}});const window={[contextName]:{map},addEventListener(){}};
const L={Polyline:Line,Polygon,polyline:(p,o)=>new Line(p,o),DomEvent:{stopPropagation(){}},popup:()=>({setLatLng(){return this},setContent(h){this.html=h;return this},openOn(){shown=this;live.add(this);return this}})};
vm.runInNewContext(fs.readFileSync('tactical-water-distance.js','utf8'),{window,L,document:{createElement:el,head:{appendChild(){}},body:{appendChild(){}},addEventListener(){}},setTimeout:()=>1,clearTimeout(){},setInterval(){},AbortController,fetch:async()=>({ok:true,json:async()=>({elevation:[10,20,15]})}),console});
water.fire('click',{latlng:{lat:51,lng:19}});await new Promise(setImmediate);
assert.ok(water.unbound);assert.match(shown.html,/50 m/);assert.match(shown.html,/3 szt./);assert.match(shown.html,/\+5 m/);assert.match(shown.html,/10 m/);return shown.html;
}
(async()=>{assert.equal(await run('firemapCtx'),await run('firemapSkCtx'));console.log('PASS: SK and terminal show identical length, hose count and elevation data, including non-default WATER style')})();
