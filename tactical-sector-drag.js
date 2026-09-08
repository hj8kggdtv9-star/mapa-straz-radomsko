(()=>{
if(window.__firemapSectorDragV2)return;window.__firemapSectorDragV2=true;
function wait(){const ctx=window.firemapCtx,api=window.firemapTacticalEditor;if(!ctx?.map||!api)return setTimeout(wait,250);init(ctx.map,api)}
function init(map,api){
 const bound=new WeakSet();let editLayer=null,handles=[];
 function clear(){const old=handles;handles=[];editLayer=null;old.forEach(h=>map.removeLayer(h))}
 function edit(layer){
  if(api.mode||api.busy||!api.enabled||!map.hasLayer(layer))return;const item=api.getItem(layer._firemapLocalKey);
  if(!item||item.category!=='SECTOR'||item.geometry_type!=='POLYGON')return;
  clear();editLayer=layer;const incident=api.incidentId;
  item.geometry.points.forEach((ll,index)=>{
   const handle=L.marker(ll,{draggable:true,autoPan:true,keyboard:false,zIndexOffset:1800,icon:L.divIcon({className:'',html:'<div class="fm-sector-handle"></div>',iconSize:[22,22],iconAnchor:[11,11]})}).addTo(map);
   let wasDragging=false;
   handle.on('dragstart',()=>{wasDragging=map.dragging.enabled();map.dragging.disable()});
   handle.on('drag',e=>{const p=e.target.getLatLng(),points=item.geometry.points.map(x=>[...x]);points[index]=[p.lat,p.lng];layer.setLatLngs(points)});
   handle.on('dragend',e=>{
    const p=e.target.getLatLng(),points=item.geometry.points.map(x=>[...x]);points[index]=[p.lat,p.lng];
    if(wasDragging&&!api.mode)map.dragging.enable();
    if(incident!==api.incidentId||!api.updateItem(layer._firemapLocalKey,{geometry:{...item.geometry,points}},'⬡ Odcinek dopasowany · NIEUDOSTĘPNIONY'))layer.setLatLngs(item.geometry.points);
    clear();
   });handles.push(handle);
  });
  document.getElementById('tacState').textContent='⬡ Przeciągnij wybrany wierzchołek odcinka.';
 }
 function bind(layer){if(!layer||bound.has(layer)||!layer._firemapLocalKey)return;const item=api.getItem(layer._firemapLocalKey);if(item?.category!=='SECTOR'||item.geometry_type!=='POLYGON')return;bound.add(layer);layer.on('click',()=>setTimeout(()=>edit(layer),0))}
 const css=document.createElement('style');css.textContent='.fm-sector-handle{width:22px;height:22px;border-radius:50%;background:#22c55e;border:3px solid #fff;box-shadow:0 2px 9px #000b;touch-action:none}';document.head.appendChild(css);
 map.on('layeradd',e=>bind(e.layer));map.on('layerremove',e=>{if(e.layer===editLayer)clear()});
 window.addEventListener('firemap:tactical:change',()=>{clear();map.eachLayer(bind)});map.eachLayer(bind);
}
wait();
})();
