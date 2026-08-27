(()=>{
const wait=()=>{const c=window.firemapCtx;if(!c?.map){setTimeout(wait,250);return}init(c.map)};
function init(map){
  const css=document.createElement('style');
  css.textContent=`.tac-radius-label{background:#111827ee!important;color:#fff!important;border:2px solid #facc15!important;border-radius:10px!important;padding:6px 9px!important;font-weight:900!important;font-size:12px!important;box-shadow:0 4px 14px #0008!important}.tac-radius-label:before{display:none!important}`;
  document.head.appendChild(css);

  let active=false,center=null,guide=null,label=null,finishing=false;
  const container=map.getContainer();

  const fmt=m=>m<1000?`${Math.round(m)} m`:`${(m/1000).toFixed(m<10000?2:1)} km`;
  const cleanup=()=>{
    active=false;center=null;finishing=false;
    if(guide){map.removeLayer(guide);guide=null}
    if(label){map.removeLayer(label);label=null}
  };
  const arm=()=>{cleanup();active=true};
  const update=ll=>{
    if(!active||!center||finishing)return;
    const r=map.distance(center,ll);
    if(!guide) guide=L.polyline([center,ll],{color:'#facc15',weight:2,dashArray:'5,5',opacity:.95,interactive:false}).addTo(map);
    else guide.setLatLngs([center,ll]);
    if(!label) label=L.tooltip({permanent:true,direction:'top',offset:[0,-10],className:'tac-radius-label',interactive:false}).setLatLng(ll).setContent(`Promień: ${fmt(r)}`).addTo(map);
    else label.setLatLng(ll).setContent(`Promień: ${fmt(r)}`);
  };

  document.addEventListener('click',e=>{
    const b=e.target.closest?.('[data-tac]');
    if(!b)return;
    if(b.dataset.tac==='DANGER') arm();
    else cleanup();
  },true);

  map.on('click',e=>{
    if(!active)return;
    if(!center){
      center=e.latlng;
      if(!label) label=L.tooltip({permanent:true,direction:'top',offset:[0,-10],className:'tac-radius-label',interactive:false}).setLatLng(center).setContent('Promień: 0 m').addTo(map);
      return;
    }
    const r=map.distance(center,e.latlng);
    finishing=true;
    update(e.latlng);
    if(label) label.setLatLng(e.latlng).setContent(`Promień: ${fmt(r)}`);
    setTimeout(cleanup,650);
  });

  map.on('mousemove',e=>update(e.latlng));

  container.addEventListener('touchmove',e=>{
    if(!active||!center||finishing||!e.touches||e.touches.length!==1)return;
    const t=e.touches[0],r=container.getBoundingClientRect();
    update(map.containerPointToLatLng([t.clientX-r.left,t.clientY-r.top]));
  },{passive:true});

  document.addEventListener('click',e=>{
    if(e.target.closest?.('#tacCancel,#tacClose,#tacDone,#tacFinish')) cleanup();
  },true);
}
wait();
})();