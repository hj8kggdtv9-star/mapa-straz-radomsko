const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const ctx={window:{}};vm.createContext(ctx);vm.runInContext(fs.readFileSync('terminal-contact.js','utf8'),ctx);const {normalize,popup}=ctx.window.firemapContact;
assert.equal(normalize(' +48 (600) 123-456 '),'+48600123456');assert.equal(normalize('600123456'),'600123456');assert.equal(normalize(''),null);assert.equal(popup(null),'');
for(const bad of ['123','1234567890123456','+48+600123456','javascript:123456789','600123456" onclick="bad']){assert.throws(()=>normalize(bad));assert.equal(popup(bad),'')}
assert.match(popup('+48600123456'),/href="tel:\+48600123456"/);
for(const f of ['vehicle.html','dispatcher.html','external-join.html']){const html=fs.readFileSync(f,'utf8');assert.match(html,/terminal-contact.js/);for(const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))new vm.Script(m[1]);}
for(const f of ['external-join.js','sk-global-positioning.js','incident-assignment-sk.js','active-vehicles-stale.js','tactical-ui.js','tactical-viewer.js'])new vm.Script(fs.readFileSync(f,'utf8'));
assert.match(fs.readFileSync('vehicle.html','utf8'),/contact_phone:myData.phone\|\|null/);
assert.match(fs.readFileSync('external-join.js','utf8'),/external_force_set_contact/);
console.log('PASS: optional contact normalization, invalid numbers/XSS rejected, tel link, all modified clients parse');
