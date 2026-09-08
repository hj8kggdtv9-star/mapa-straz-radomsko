(()=>{
function wait(){const map=window.firemapCtx?.map,api=window.firemapTacticalEditor;if(!map||!api)return setTimeout(wait,250);init(map,api)}
function init(map,api){
 let guide=null,label=null;
 const css=document.createElement('style');css.textContent='.tac-radius-label{background:#111827ee!important;color:#fff!important;border:2px solid #facc15!important;border-radius:10px!important;padding:6px 9px!important;font-weight:900!important}';document.head.appendChild(css);
 function clear(){if(guide){map.removeLayer(guide);guide=null}if(label){map.removeLayer(label);label=null}}
 function update(ll){const center=api.center;if(api.mode!=='DANGER'||!center||api.multiTouch){clear();return}const r=map.distance(center,ll),text='Promień: '+(r<1000?Math.round(r)+' m':(r/1000).toFixed(2)+' km');if(!guide)guide=L.polyline([center,ll],{color:'#facc15',weight:2,dashArray:'5,5',interactive:false}).addTo(map);else guide.setLatLngs([center,ll]);if(!label)label=L.tooltip({permanent:true,direction:'top',className:'tac-radius-label',interactive:false}).setLatLng(ll).setContent(text).addTo(map);else label.setLatLng(ll).setContent(text)}
 map.on('mousemove',e=>update(e.latlng));window.addEventListener('firemap:tactical:change',()=>{clear();if(api.mode==='DANGER'&&api.center)update(api.center)});
 const c=map.getContainer();c.addEventListener('touchmove',e=>{if(e.touches?.length!==1)return;const t=e.touches[0],r=c.getBoundingClientRect();update(map.containerPointToLatLng([t.clientX-r.left,t.clientY-r.top]))},{passive:true});
}
wait();
})();
