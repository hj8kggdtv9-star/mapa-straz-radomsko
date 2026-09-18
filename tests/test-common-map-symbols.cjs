const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const ctx={window:{},document:{createElement:()=>({}),head:{appendChild(){}}},L:{divIcon:x=>x}};vm.runInNewContext(fs.readFileSync('map-symbols.js','utf8'),ctx);
const s=ctx.window.firemapSymbols;
for(const [type,glyph] of [['KDR','⭐'],['GBA','🚒'],['QUAD','🏍️'],['SD','🪜'],['SLOP','🚗'],['SLRT','🚐'],['MIKROBUS','🚌']]){assert.equal(s.glyph(type),glyph);assert.ok(s.vehicle({vehicle_type:type,status:'ON_SCENE'}).html.includes(glyph))}
assert.match(s.vehicle({vehicle_type:'KDR'}).html,/#ca8a04/);assert.match(s.vehicle({vehicle_type:'GBA',status:'ON_SCENE'}).html,/#dc2626/);assert.match(s.vehicle({vehicle_type:'KDR'},{stale:true}).html,/fm-symbol-warning/);
assert.doesNotMatch(s.vehicle({call_sign:'<img>',vehicle_type:'GBA'},{own:true}).html,/<img>/);
for(const file of ['vehicle.html','dispatcher.html','external-join.html'])assert.match(fs.readFileSync(file,'utf8'),/map-symbols.js/);
for(const file of ['external-join.js','sk-global-positioning.js','active-vehicles-stale.js','incident-assignment-sk.js','tactical-water-distance.js','tactical-ui-core.js'])new vm.Script(fs.readFileSync(file,'utf8'));
assert.match(fs.readFileSync('tactical-viewer.js','utf8'),/load\('tactical-shared-viewer.js'\);load\('tactical-water-distance.js'\)/);
console.log('PASS: shared vehicle types, KDR, colors, stale symbols, escaped labels and shared SK tactical modules');
