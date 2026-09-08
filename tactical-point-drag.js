(()=>{
if(window.__firemapPointDragV2)return;window.__firemapPointDragV2=true;
function wait(){const ctx=window.firemapCtx,api=window.firemapTacticalEditor;if(!ctx?.map||!api)return setTimeout(wait,250);init(ctx.map,api)}
function init(map,api){
 const bound=new WeakSet();
 function bind(layer){
  if(!layer||bound.has(layer)||!layer._firemapLocalKey||!layer.dragging)return;
  const item=api.getItem(layer._firemapLocalKey);if(!item?.style?.point&&item?.category!=='POINT')return;
  bound.add(layer);layer.options.draggable=true;
  if(api.enabled&&!api.mode&&!api.busy)layer.dragging.enable();else layer.dragging.disable();
  let start=null,wasDragging=false;
  layer.on('dragstart',()=>{const p=layer.getLatLng();start=[p.lat,p.lng];wasDragging=map.dragging.enabled();map.dragging.disable()});
  layer.on('dragend',()=>{
   const p=layer.getLatLng();if(wasDragging&&!api.mode)map.dragging.enable();
   if(!start)return;const item=api.getItem(layer._firemapLocalKey);
   if(!item||layer._firemapIncidentId!==api.incidentId||!api.updateItem(layer._firemapLocalKey,{geometry:{...item.geometry,center:[p.lat,p.lng]}},'📍 Punkt przesunięty · NIEUDOSTĘPNIONY'))layer.setLatLng(start);
   start=null;
  });
 }
 function refresh(){map.eachLayer(layer=>{bind(layer);if(bound.has(layer)){if(api.enabled&&!api.mode&&!api.busy)layer.dragging.enable();else layer.dragging.disable()}})}
 map.on('layeradd',e=>bind(e.layer));window.addEventListener('firemap:tactical:change',refresh);refresh();
}
wait();
})();
