(()=>{
const URL='https://vqgipvwcvbhabvfipodl.supabase.co';
const KEY='sb_publishable_BYEVImorGhltw1aCaRXyRQ_pM2hKMkI';
const sb=supabase.createClient(URL,KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
const optionalNumber=v=>v!==null&&v!==undefined&&Number.isFinite(+v)?+v:null;
const $=id=>document.getElementById(id),STORE='firemapExternalGuestV2';
const PROVINCES=['Dolnośląskie','Kujawsko-pomorskie','Lubelskie','Lubuskie','Łódzkie','Małopolskie','Mazowieckie','Opolskie','Podkarpackie','Podlaskie','Pomorskie','Śląskie','Świętokrzyskie','Warmińsko-mazurskie','Wielkopolskie','Zachodniopomorskie'];
$('province').innerHTML='<option value="">— wybierz województwo —</option>'+PROVINCES.map(x=>`<option>${x}</option>`).join('');
$('code').value=(new URLSearchParams(location.search).get('code')||'').replace(/\D/g,'').slice(0,6);
let state=read(),map=null,selfMarker=null,incidentMarker=null,watchId=null,lastSend=0,lastPos=null,currentStatus='DISPATCHED',sending=false,pendingSend=false,leaving=false;
const peerMarkers=new Map();let peersBusy=false,peersTimer=null,peerRows=[];
const STATUS_VIEW={DISPATCHED:{label:'WYJAZD',color:'#f59e0b'},ON_SCENE:{label:'NA MIEJSCU',color:'#dc2626'},RETURNING:{label:'KONIEC',color:'#2563eb'}};
function vehicleIcon(status,stale=false){const v=STATUS_VIEW[status]||STATUS_VIEW.DISPATCHED;return L.divIcon({className:'',html:`<div style="width:34px;height:34px;border:3px solid white;border-radius:10px;background:${stale?'#64748b':v.color};display:grid;place-items:center;font-size:20px;box-shadow:0 2px 8px #0008">🚒</div>`,iconSize:[38,38],iconAnchor:[19,19]})}
function clearPeers(){for(const m of peerMarkers.values())map.removeLayer(m);peerMarkers.clear();peerRows=[];if($('peersList'))$('peersList').innerHTML=''}
function expireSession(){stopGps();leaving=true;clear();clearPeers();if(peersTimer){clearInterval(peersTimer);peersTimer=null}$('info').textContent='Sesja wygasła lub zdarzenie zakończone.';setTimeout(()=>{location.href=location.pathname},2500)}
async function refreshPeers(){
 if(peersBusy||leaving||!map||!state?.session_token)return;peersBusy=true;
 try{
  const {data,error}=await sb.rpc('external_force_peers',{p_session_token:state.session_token});if(error)throw error;if(leaving)return;
  const rows=(Array.isArray(data)?data:[]).filter(v=>v.id!==state.vehicle_id&&v.status!=='BASE'&&v.lat!==null&&v.lng!==null&&Number.isFinite(+v.lat)&&Number.isFinite(+v.lng));
  peerRows=rows;const seen=new Set();
  rows.forEach((v,index)=>{
   seen.add(v.id);const age=Math.max(0,Math.round((Date.now()-Date.parse(v.updated_at))/1000)),stale=!Number.isFinite(age)||age>180,style=STATUS_VIEW[v.status]||STATUS_VIEW.DISPATCHED,icon=vehicleIcon(v.status,stale);
   let m=peerMarkers.get(v.id);if(!m){m=L.marker([+v.lat,+v.lng],{icon,zIndexOffset:200}).addTo(map);peerMarkers.set(v.id,m)}else{m.setLatLng([+v.lat,+v.lng]);m.setIcon(icon)}
   m.bindTooltip(esc(v.call_sign),{permanent:true,direction:index%2?'left':'right',offset:[index%2?-22:22,18*Math.floor(index/2)],className:'peer-label'});
   m.bindPopup(`<b>${esc(v.call_sign)} · ${esc(v.vehicle_type)}</b><br>${esc(v.unit_name)}<br>${esc(v.force_group)}${v.specialist_group?' · '+esc(specLabel(v.specialist_group)):''}<br><b>${style.label}</b><br>${stale?'⚠ Ostatnia znana pozycja':'Pozycja'} · ${Number.isFinite(age)?age+' s temu':'brak czasu'}`);
  });
  for(const[id,m]of peerMarkers)if(!seen.has(id)){map.removeLayer(m);peerMarkers.delete(id)}
  $('peersState').textContent='Inne zastępy w zdarzeniu: '+rows.length;
  $('peersList').innerHTML=rows.length?rows.map(v=>`<button type="button" data-peer-id="${esc(v.id)}" class="peer-row">${esc(v.call_sign)} · ${esc(v.vehicle_type)} · ${(STATUS_VIEW[v.status]||STATUS_VIEW.DISPATCHED).label}</button>`).join(''):'<small>Brak innych zastępów z przesłaną pozycją GPS.</small>';
  $('peersList').querySelectorAll('[data-peer-id]').forEach(b=>b.onclick=()=>{const m=peerMarkers.get(b.dataset.peerId);if(m){map.flyTo(m.getLatLng(),16);m.openPopup()}});
 }catch(error){
  if(error?.code==='P0001'&&error.message==='Sesja wygasła'){expireSession();return}
  $('peersState').textContent='Brak aktualizacji zastępów — ostatni podgląd może być nieaktualny.';
 }finally{peersBusy=false}
}
function startPeers(){refreshPeers();if(!peersTimer)peersTimer=setInterval(()=>{if(!document.hidden)refreshPeers()},3000)}
function read(){try{return JSON.parse(localStorage.getItem(STORE)||'null')}catch{return null}}
function save(){localStorage.setItem(STORE,JSON.stringify(state))}
function clear(){localStorage.removeItem(STORE)}
function specLabel(s){return({CHEM_ECO:'chem-eko',WATER_DIVE:'wodno-nurkowa',HEIGHT:'wysokościowa',TECH_SEARCH:'techniczna/poszukiwawcza',USAR:'USAR',DRONE:'dronowa',OTHER:'specjalistyczna'})[s]||''}
function badge(g){if(g==='LOCAL')return'<span class="badge ext">POWIAT</span>';if(g==='WOO')return'<span class="badge">WOO</span>';if(g==='COO')return'<span class="badge coo">COO</span>';return'<span class="badge ext">ZEWN.</span>'}
function showLive(){
 $('joinCover').style.display='none';$('live').style.display='block';
 if(!map){map=L.map('map',{minZoom:3}).setView([state.incident_lat,state.incident_lng],14);L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© OpenStreetMap'}).addTo(map);incidentMarker=L.marker([state.incident_lat,state.incident_lng]).addTo(map).bindPopup(`<b>${state.incident_kind==='FIRE'?'🔥 POŻAR':'⚠️ MZ'}</b><br>${esc(state.incident_description||'Zdarzenie')}`)}
 $('title').innerHTML=`FIREMAP ${badge(state.force_group)} · ${esc(state.call_sign)}`;
 $('info').textContent=`${state.origin_unit} · ${state.origin_county}${state.specialist_group?' · '+specLabel(state.specialist_group):''}`;
 setStatus(['DISPATCHED','ON_SCENE','RETURNING'].includes(state.status)?state.status:'DISPATCHED',false);startGps();startPeers();setTimeout(()=>map.invalidateSize(),100);
}
function stopGps(){if(watchId!==null){navigator.geolocation.clearWatch(watchId);watchId=null}}
async function send(pos,force=false){
 if(leaving||!state?.session_token||!pos?.coords)return;
 if(sending){pendingSend=true;return}
 const now=Date.now();if(!force&&now-lastSend<1800)return;lastSend=now;sending=true;
 const speed=optionalNumber(pos.coords.speed);
 const p={p_session_token:state.session_token,p_lat:+pos.coords.latitude,p_lng:+pos.coords.longitude,p_status:currentStatus,p_accuracy:optionalNumber(pos.coords.accuracy),p_speed:speed===null?null:Math.max(0,speed*3.6),p_heading:optionalNumber(pos.coords.heading)};
 try{
  const {error}=await sb.rpc('external_force_update',p);
  if(error)throw error;
  const ll=[p.p_lat,p.p_lng];if(!selfMarker)selfMarker=L.marker(ll,{icon:vehicleIcon(currentStatus)}).addTo(map).bindTooltip(esc(state.call_sign)+' · TY',{permanent:true,direction:'top',offset:[0,-20]}).bindPopup(`<b>${esc(state.call_sign)}</b><br>${esc(state.origin_unit)}`);else{selfMarker.setLatLng(ll);selfMarker.setIcon(vehicleIcon(currentStatus))}
  $('info').textContent=`${state.origin_unit} · ${state.origin_county} · pozycja i status wysłane`;
 }catch(error){
  if(error?.code==='P0001'&&/^(Sesja wygasła|Zdarzenie zostało zakończone)[.!]?$/.test(error.message||'')){
   expireSession();
  }else{
   $('info').textContent='Nie wysłano pozycji/statusu. Sesja zachowana — ponowię połączenie.';lastSend=0;
  }
 }finally{
  sending=false;if(pendingSend&&!leaving){pendingSend=false;if(lastPos)send(lastPos,true)}
 }
}
function startGps(){if(watchId!==null)return;if(!navigator.geolocation){$('info').textContent='Brak obsługi GPS';return}watchId=navigator.geolocation.watchPosition(p=>{lastPos=p;send(p)},e=>{$('info').textContent='GPS: '+(e.message||'brak pozycji')},{enableHighAccuracy:true,maximumAge:1000,timeout:15000})}
async function leaveSession(){
 if(leaving)return;leaving=true;stopGps();
 try{
  if(state?.session_token){const {error}=await sb.rpc('external_force_leave',{p_session_token:state.session_token});if(error)throw error}
  clearPeers();if(peersTimer){clearInterval(peersTimer);peersTimer=null}clear();location.href=location.pathname;
 }catch(error){leaving=false;$('info').textContent='Nie udało się opuścić zdarzenia. Sprawdź połączenie i spróbuj ponownie.';startGps()}
}
function setStatus(s,sendNow=true){if(s==='BASE'){leaveSession();return}currentStatus=s;if(state){state.status=s;save()}document.querySelectorAll('[data-s]').forEach(b=>b.classList.toggle('active',b.dataset.s===s));if(sendNow){if(lastPos)send(lastPos,true);else $('info').textContent='Status oczekuje na pozycję GPS.'}}
async function join(){
 const payload={p_code:$('code').value.replace(/\D/g,''),p_force_group:$('forceGroup').value,p_specialist_group:$('spec').value||null,p_voivodeship:$('province').value,p_county:$('county').value.trim(),p_unit:$('unit').value.trim(),p_call_sign:$('call').value.trim(),p_vehicle_type:$('type').value};
 if(payload.p_code.length!==6||!payload.p_voivodeship||!payload.p_county||!payload.p_unit||!payload.p_call_sign){$('msg').textContent='Uzupełnij kod, województwo, powiat, jednostkę i kryptonim.';return}
 $('joinBtn').disabled=true;$('msg').textContent='Weryfikuję kod…';const {data,error}=await sb.rpc('external_force_join',payload);$('joinBtn').disabled=false;if(error){$('msg').textContent=error.message||'Nie udało się dołączyć.';return}
 const x=Array.isArray(data)?data[0]:data;if(!x?.session_token){$('msg').textContent='Nieprawidłowa odpowiedź serwera.';return}
 state={...x,force_group:payload.p_force_group,specialist_group:payload.p_specialist_group,origin_voivodeship:payload.p_voivodeship,origin_county:payload.p_county,origin_unit:payload.p_unit,call_sign:payload.p_call_sign,vehicle_type:payload.p_vehicle_type};save();$('msg').textContent='Dołączono. Uruchamiam GPS…';setTimeout(showLive,250);
}
$('joinBtn').onclick=join;$('center').onclick=()=>{if(lastPos)map.flyTo([lastPos.coords.latitude,lastPos.coords.longitude],15,{duration:.4})};$('leave').onclick=()=>{if(confirm('Zakończyć udział tego zastępu w zdarzeniu?'))leaveSession()};document.querySelectorAll('[data-s]').forEach(b=>b.onclick=()=>setStatus(b.dataset.s));
window.addEventListener('online',()=>{if(lastPos&&!leaving)send(lastPos,true);refreshPeers()});
window.addEventListener('focus',refreshPeers);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)refreshPeers()});
$('showPeers').onclick=()=>{const points=peerRows.map(v=>[+v.lat,+v.lng]);if(lastPos)points.push([lastPos.coords.latitude,lastPos.coords.longitude]);if(points.length)map.fitBounds(L.latLngBounds(points),{padding:[60,100],maxZoom:16})};
if(state?.session_token)showLive();
})();

