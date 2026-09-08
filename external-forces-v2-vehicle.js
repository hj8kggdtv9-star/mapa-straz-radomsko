(()=>{
if(window.__firemapExternalForcesVehicleV2)return;window.__firemapExternalForcesVehicleV2=true;
const STORE='firemapForceOrigin';
const SPEC=[['','— brak / zwykły zastęp —'],['CHEM_ECO','Ratownictwo chemiczno-ekologiczne'],['WATER_DIVE','Ratownictwo wodno-nurkowe'],['HEIGHT','Ratownictwo wysokościowe'],['TECH_SEARCH','Ratownictwo techniczne / poszukiwawcze'],['USAR','Grupa USAR'],['DRONE','Grupa dronowa'],['OTHER','Inna grupa specjalistyczna']];
function read(){try{return JSON.parse(localStorage.getItem(STORE)||'null')||{group:'LOCAL'}}catch{return{group:'LOCAL'}}}
function write(x){localStorage.setItem(STORE,JSON.stringify(x))}
function wait(){const c=window.firemapCtx,box=document.getElementById('fmForceOriginBox');if(!c?.sb||!box)return setTimeout(wait,250);init(c,box)}
function init({sb},box){
 const ext=document.getElementById('fmForceExternal');if(ext&&!document.getElementById('fmForceSpecialist')){const wrap=document.createElement('div');wrap.innerHTML='<label>Grupa specjalistyczna</label><select id="fmForceSpecialist">'+SPEC.map(([v,n])=>`<option value="${v}">${n}</option>`).join('')+'</select><div style="font-size:11px;color:#fcd34d;margin-top:4px">Opcjonalnie — niezależnie od WOO/COO.</div>';ext.insertBefore(wrap,ext.lastElementChild);const sel=wrap.querySelector('#fmForceSpecialist'),x=read();sel.value=x.specialist||'';sel.onchange=()=>{const y=read();y.specialist=sel.value||'';write(y)}}
 const originalFrom=sb.from.bind(sb);sb.from=function(table){const b=originalFrom(table);if(table!=='vehicles'||!b)return b;const up=b.upsert?.bind(b);if(up)b.upsert=(values,opts)=>{const x=read(),enrich=v=>{if(!v||typeof v!=='object')return v;const external=x.group==='WOO'||x.group==='COO';return{...v,force_group:external?x.group:'LOCAL',specialist_group:external?(x.specialist||null):null,origin_voivodeship:external?(x.province||null):null,origin_county:external?(x.county||null):null,origin_unit:external?(x.unit||null):null}};return up(Array.isArray(values)?values.map(enrich):enrich(values),opts)};return b};
}
wait();
})();
