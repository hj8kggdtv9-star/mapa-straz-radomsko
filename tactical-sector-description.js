(()=>{
if(window.__firemapDescriptionV2)return;window.__firemapDescriptionV2=true;
function wait(){const ctx=window.firemapCtx,api=window.firemapTacticalEditor;if(!ctx?.map||!api)return setTimeout(wait,250);init(ctx,api)}
function init({map,session},api){
const css=document.createElement('style');css.textContent='.fm-sector-desc{position:fixed;z-index:1340;left:50%;bottom:0;transform:translate(-50%,105%);width:min(500px,100%);background:#0a1626;border:1px solid #475569;border-radius:20px 20px 0 0;padding:16px 16px max(18px,env(safe-area-inset-bottom));box-shadow:0 -20px 50px #0009;color:#fff;transition:.18s}.fm-sector-desc.open{transform:translate(-50%,0)}.fm-sector-desc h3{margin:0 0 8px}.fm-sector-desc label{display:block;font-size:12px;color:#cbd5e1;margin:8px 0 4px}.fm-sector-desc input,.fm-sector-desc textarea{box-sizing:border-box;width:100%;background:#111e30;color:#fff;border:1px solid #475569;border-radius:10px;padding:10px;font:inherit}.fm-sector-desc input{height:44px}.fm-sector-desc textarea{min-height:86px;resize:vertical}.fm-sector-desc-actions{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:12px}.fm-sector-desc button{min-height:46px;border:0;border-radius:11px;background:#334155;color:#fff;font-weight:900}.fm-sector-desc .save{background:#166534}';document.head.appendChild(css);
const ed=document.createElement('div');ed.className='fm-sector-desc';
ed.innerHTML='<h3 id="fmDescTitle">Opis elementu</h3><label for="fmSectorName">Nazwa / godzina</label><input id="fmSectorName" maxlength="60"><label for="fmSectorDesc">Opis</label><textarea id="fmSectorDesc" maxlength="300"></textarea><div class="fm-sector-desc-actions"><button id="fmSectorCancel">Anuluj</button><button class="save" id="fmSectorSave">Zapisz opis</button></div>';
document.body.appendChild(ed);
const $=id=>document.getElementById(id),button=document.createElement('button');button.id='fmDescribeSelected';button.textContent='✎ Edytuj opis / godzinę';
button.style.cssText='display:none;position:fixed;z-index:1240;left:50%;transform:translateX(-50%);bottom:145px;width:auto;min-height:44px;padding:8px 16px;border:2px solid #fff;border-radius:12px;background:#334155;color:white;font-weight:800';
document.body.appendChild(button);let current=null;
function item(key){const d=api.getItem(key);return api.enabled&&!api.mode&&!api.busy&&d&&(!d.created_by||d.created_by===session.user.id)&&((d.category==='SECTOR'&&d.geometry_type==='POLYGON')||d.category==='FIRE_SPREAD')?d:null}
function close(){ed.classList.remove('open');current=null;refresh()}
function open(key){
 const d=item(key);if(!d)return;current={key,incident:api.incidentId};
 const fire=d.category==='FIRE_SPREAD';
 $('fmDescTitle').textContent=fire?'🔴 Zasięg pożaru — opis / godzina':'⬡ Opis odcinka bojowego';
 $('fmSectorName').value=d.style?.sectorName||d.label||'';
 $('fmSectorName').placeholder=fire?'np. Zasięg pożaru, godz. 14:30':'np. Odcinek I — natarcie';
 $('fmSectorDesc').value=d.style?.sectorDescription||'';
 $('fmSectorDesc').placeholder=fire?'np. Linia granicy pożaru o wskazanej godzinie':'Zadania, siły i uwagi dla odcinka';
 ed.classList.add('open');button.style.display='none';
}
$('fmSectorCancel').onclick=close;
$('fmSectorSave').onclick=()=>{
 if(!current||current.incident!==api.incidentId)return close();
 const d=item(current.key);if(!d)return close();
 const name=$('fmSectorName').value.trim()||(d.category==='FIRE_SPREAD'?'Zasięg pożaru':'Odcinek bojowy'),description=$('fmSectorDesc').value.trim();
 if(api.updateItem(current.key,{label:name,style:{...(d.style||{}),sectorName:name,sectorDescription:description}},'Opis zapisany w szkicu. Wybierz „Zapisz i udostępnij”, aby pokazać go innym.'))close();
};
button.onclick=()=>open(api.selectedKey);
function refresh(){if(current&&(current.incident!==api.incidentId||!item(current.key)))current=null;if(!current)ed.classList.remove('open');button.style.display=!current&&item(api.selectedKey)?'block':'none'}
const bound=new WeakSet();
function bind(layer){if(!layer?._firemapLocalKey||bound.has(layer))return;bound.add(layer);layer.on('dblclick',e=>{L.DomEvent.stop(e);open(layer._firemapLocalKey)});layer.on('contextmenu',e=>{L.DomEvent.stop(e);open(layer._firemapLocalKey)})}
map.on('layeradd',e=>bind(e.layer));map.eachLayer(bind);
window.addEventListener('firemap:tactical:change',refresh);
window.addEventListener('firemap:tactical:describe',e=>open(e.detail?.key));
refresh();
}
wait();
})();
