(()=>{
const wait=()=>{const ctx=window.firemapCtx;if(!ctx?.map){setTimeout(wait,250);return}init(ctx.map)};
function init(map){
  if(window.__firemapDriveFocus)return; window.__firemapDriveFocus=true;
  let pausedUntil=0,lastFix=null,lastAt=0;
  const container=map.getContainer();
  function driveOn(){return localStorage.getItem('firemapDriveMode')==='1'}
  function targetY(){
    const h=container.clientHeight||window.innerHeight;
    const quick=document.getElementById('quick');
    let y=h*0.72;
    if(quick){const r=quick.getBoundingClientRect(),mr=container.getBoundingClientRect();const top=r.top-mr.top;if(Number.isFinite(top)&&top>0)y=Math.min(y,top-105)}
    return Math.max(h*0.62,Math.min(h*0.75,y));
  }
  function place(lat,lng){
    if(!driveOn()||Date.now()<pausedUntil)return;
    if(!Number.isFinite(lat)||!Number.isFinite(lng))return;
    const h=container.clientHeight||window.innerHeight;
    const zoom=Math.max(map.getZoom(),15);
    map.setView([lat,lng],zoom,{animate:false});
    const dy=targetY()-h/2;
    if(dy>20)map.panBy([0,-dy],{animate:false});
  }
  function onPos(pos){
    if(!driveOn()||!pos?.coords)return;
    const lat=+pos.coords.latitude,lng=+pos.coords.longitude;
    if(!Number.isFinite(lat)||!Number.isFinite(lng))return;
    const now=Date.now();
    if(now-lastAt<700)return;
    lastAt=now;lastFix=[lat,lng];
    requestAnimationFrame(()=>place(lat,lng));
  }
  if(navigator.geolocation){
    navigator.geolocation.watchPosition(onPos,()=>{}, {enableHighAccuracy:true,maximumAge:1000,timeout:15000});
  }
  ['pointerdown','touchstart','wheel'].forEach(ev=>container.addEventListener(ev,()=>{
    if(!driveOn())return;
    pausedUntil=Date.now()+9000;
    setTimeout(()=>{if(driveOn()&&lastFix&&Date.now()>=pausedUntil)place(lastFix[0],lastFix[1])},9200);
  },{passive:true}));
  document.getElementById('driveBtn')?.addEventListener('click',()=>setTimeout(()=>{if(driveOn()&&lastFix)place(lastFix[0],lastFix[1])},250));
  document.getElementById('followBtn')?.addEventListener('click',()=>{pausedUntil=0;setTimeout(()=>{if(driveOn()&&lastFix)place(lastFix[0],lastFix[1])},100)});
}
wait();
})();