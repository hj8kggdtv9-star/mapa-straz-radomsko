(()=>{if(window.__firemapFollowFixV2)return;window.__firemapFollowFixV2=true;
const wait=()=>{const c=window.firemapCtx,btn=document.getElementById('followBtn');if(!c?.map||!btn||!window.L)return setTimeout(wait,200);init(c.map,btn)};
function init(map,btn){
  let busy=false,clearActive=null;

  // FIREMAP Zastęp ma działać również poza powiatem radomszczańskim.
  // vehicle.html używa historycznego BOUNDS zarówno jako maxBounds mapy,
  // jak i filtra publikacji/wyświetlania pojazdów. Zdejmujemy ograniczenie mapy
  // i neutralizujemy wyłącznie ten jeden stary prostokąt powiatu.
  try{map.setMaxBounds(null)}catch{}
  try{map.options.maxBounds=null}catch{}

  if(!window.__firemapGlobalVehicleBoundsPatch){
    window.__firemapGlobalVehicleBoundsPatch=true;
    const proto=L.LatLngBounds&&L.LatLngBounds.prototype;
    const original=proto?.contains;
    if(original){
      proto.contains=function(obj){
        try{
          const sw=this.getSouthWest?.(),ne=this.getNorthEast?.();
          const isLegacyCountyBounds=sw&&ne&&
            Math.abs(sw.lat-50.58)<0.001&&Math.abs(sw.lng-18.55)<0.001&&
            Math.abs(ne.lat-51.55)<0.001&&Math.abs(ne.lng-20.48)<0.001;
          if(isLegacyCountyBounds)return true;
        }catch{}
        return original.call(this,obj);
      };
    }
  }

  function releaseBounds(){
    try{if(map.options.maxBounds)map.setMaxBounds(null)}catch{}
    try{map.options.maxBounds=null}catch{}
  }
  function toast(msg){const t=document.getElementById('toast');if(!t)return;try{t.textContent=msg;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),2200)}catch{}}
  function showActive(){btn.classList.add('active');clearTimeout(clearActive);clearActive=setTimeout(()=>btn.classList.remove('active'),2500)}
  function center(p){
    const lat=Number(p?.coords?.latitude),lng=Number(p?.coords?.longitude);
    if(!Number.isFinite(lat)||!Number.isFinite(lng))return false;
    releaseBounds();showActive();
    const z=Math.max(map.getZoom(),15);
    try{map.stop?.();map.flyTo([lat,lng],z,{duration:.45})}catch{map.setView([lat,lng],z)}
    return true;
  }
  btn.addEventListener('click',()=>{
    releaseBounds();showActive();
    if(!navigator.geolocation){toast('Brak obsługi GPS');return}
    if(busy)return;
    busy=true;
    navigator.geolocation.getCurrentPosition(p=>{busy=false;if(center(p))toast('📍 Pokazuję aktualną pozycję GPS')},e=>{busy=false;console.warn('FIREMAP recenter GPS',e);toast('Nie udało się pobrać aktualnej pozycji GPS')},{enableHighAccuracy:true,maximumAge:0,timeout:10000});
  });
  btn.title='Pokaż moją aktualną pozycję GPS — także poza powiatem';

  // Zabezpieczenie przed ponownym ustawieniem ograniczeń przez starszy kod/cache.
  setInterval(releaseBounds,3000);
}
wait();
})();