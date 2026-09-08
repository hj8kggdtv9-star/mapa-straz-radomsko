(()=>{
const URL='https://vqgipvwcvbhabvfipodl.supabase.co';
const KEY='sb_publishable_BYEVImorGhltw1aCaRXyRQ_pM2hKMkI';
const sb=supabase.createClient(URL,KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const $=id=>document.getElementById(id),STORE='firemapExternalGuestV2';
const PROVINCES=['Dolnośląskie','Kujawsko-pomorskie','Lubelskie','Lubuskie','Łódzkie','Małopolskie','Mazowieckie','Opolskie','Podkarpackie','Podlaskie','Pomorskie','Śląskie','Świętokrzyskie','Warmińsko-mazurskie','Wielkopolskie','Zachodniopomorskie'];
$('province').innerHTML='<option value="">— wybierz województwo —</option>'+PROVINCES.map(x=>`<option>${x}</option>`).join('');
$('code').value=(new URLSearchParams(location.search).get('code')||'').replace(/\D/g,'').slice(0,6);
let state=read(),map=null,selfMarker=null,incidentMarker=null,watchId=null,lastSend=0,lastPos=null,currentStatus='DISPATCHED';
function read(){try{return JSON.parse(localStorage.getItem(STORE)||'null')}catch{return null}}
function save(){localStorage.setItem(STORE,JSON.stringify(state))}
function clear(){localStorage.removeItem(STORE)}
function specLabel(s){return({CHEM_ECO:'chem-eko',WATER_DIVE:'wodno-nurkowa',HEIGHT:'wysokościowa',TECH_SEARCH:'techniczna/poszukiwawcza',USAR:'USAR',DRONE:'dronowa',OTHER:'specjalistyczna'})[s]||''}
function badge(g){if(g==='WOO')return'<span class="badge">WOO</span>';if(g==='COO')return'<span class="badge coo">COO</span>';return'<span class="badge ext">ZEWN.</span>'}
function showLive(){
 $('joinCover').style.display='none';$('live').style.display='block';
 if(!map){map=L.map('map',{minZoom:3}).setView([state.incident_lat,state.incident_lng],14);L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© OpenStreetMap'}).addTo(map);incidentMarker=L.marker([state.incident_lat,state.incident_lng]).addTo(map).bindPopup(`<b>${state.incident_kind==='FIRE'?'🔥 POŻAR':'⚠️ MZ'}</b><br>${state.incident_description||'Zdarzenie'}`)}
 $('title').innerHTML=`FIREMAP ${badge(state.force_group)} · ${state.call_sign}`;
 $('info').textContent=`${state.origin_unit} · ${state.origin_county}${state.specialist_group?' · '+specLabel(state.specialist_group):''}`;
 setStatus('DISPATCHED',false);startGps();setTimeout(()=>map.invalidateSize(),100);
}
function stopGps(){if(watchId!==null){navigator.geolocation.clearWatch(watchId);watchId=null}}
async function send(pos,force=false){
 if(!state?.session_token||!pos?.coords)return;const now=Date.now();if(!force&&now-lastSend<1800)return;lastSend=now;
 const p={p_session_token:state.session_token,p_lat:+pos.coords.latitude,p_lng:+pos.coords.longitude,p_status:currentStatus,p_accuracy:Number.isFinite(+pos.coords.accuracy)?+pos.coords.accuracy:null,p_speed:Number.isFinite(+pos.coords.speed)?Math.max(0,+pos.coords.speed*3.6):null,p_heading:Number.isFinite(+pos.coords.heading)?+pos.coords.heading:null};
 const {error}=await sb.rpc('external_force_update',p);
 if(error){$('info').textContent='Sesja wygasła lub zdarzenie zakończone.';stopGps();setTimeout(()=>{clear();location.href=location.pathname},2500);return}
 lastPos=pos;const ll=[p.p_lat,p.p_lng];if(!selfMarker)selfMarker=L.marker(ll).addTo(map).bindPopup(`<b>${state.call_sign}</b><br>${state.origin_unit}`);else selfMarker.setLatLng(ll);
}
function startGps(){if(watchId!==null)return;if(!navigator.geolocation){$('info').textContent='Brak obsługi GPS';return}watchId=navigator.geolocation.watchPosition(p=>{lastPos=p;send(p)},e=>{$('info').textContent='GPS: '+(e.message||'brak pozycji')},{enableHighAccuracy:true,maximumAge:1000,timeout:15000})}
async function leaveSession(){stopGps();if(state?.session_token)await sb.rpc('external_force_leave',{p_session_token:state.session_token});clear();location.href=location.pathname}
function setStatus(s,sendNow=true){currentStatus=s;document.querySelectorAll('[data-s]').forEach(b=>b.classList.toggle('active',b.dataset.s===s));if(s==='BASE'){leaveSession();return}if(sendNow&&lastPos)send(lastPos,true)}
async function join(){
 const payload={p_code:$('code').value.replace(/\D/g,''),p_force_group:$('forceGroup').value,p_specialist_group:$('spec').value||null,p_voivodeship:$('province').value,p_county:$('county').value.trim(),p_unit:$('unit').value.trim(),p_call_sign:$('call').value.trim(),p_vehicle_type:$('type').value};
 if(payload.p_code.length!==6||!payload.p_voivodeship||!payload.p_county||!payload.p_unit||!payload.p_call_sign){$('msg').textContent='Uzupełnij kod, województwo, powiat, jednostkę i kryptonim.';return}
 $('joinBtn').disabled=true;$('msg').textContent='Weryfikuję kod…';const {data,error}=await sb.rpc('external_force_join',payload);$('joinBtn').disabled=false;if(error){$('msg').textContent=error.message||'Nie udało się dołączyć.';return}
 const x=Array.isArray(data)?data[0]:data;if(!x?.session_token){$('msg').textContent='Nieprawidłowa odpowiedź serwera.';return}
 state={...x,force_group:payload.p_force_group,specialist_group:payload.p_specialist_group,origin_voivodeship:payload.p_voivodeship,origin_county:payload.p_county,origin_unit:payload.p_unit,call_sign:payload.p_call_sign,vehicle_type:payload.p_vehicle_type};save();$('msg').textContent='Dołączono. Uruchamiam GPS…';setTimeout(showLive,250);
}
$('joinBtn').onclick=join;$('center').onclick=()=>{if(lastPos)map.flyTo([lastPos.coords.latitude,lastPos.coords.longitude],15,{duration:.4})};$('leave').onclick=()=>{if(confirm('Zakończyć udział tego zastępu w zdarzeniu?'))leaveSession()};document.querySelectorAll('[data-s]').forEach(b=>b.onclick=()=>setStatus(b.dataset.s));
if(state?.session_token)showLive();
})();
