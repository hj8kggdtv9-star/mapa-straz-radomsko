(async()=>{
const sb=supabase.createClient('https://vqgipvwcvbhabvfipodl.supabase.co','sb_publishable_BYEVImorGhltw1aCaRXyRQ_pM2hKMkI');
const $=id=>document.getElementById(id),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const map=L.map('map',{zoomControl:false,attributionControl:false,dragging:false,scrollWheelZoom:false}).setView([52,19],6);L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
const wrap=document.createElement('div');wrap.innerHTML='<label>Rodzaj dostępu</label><select id="countyRole"><option value="UNIT">Jednostka OSP / JRG</option><option value="SK">SK powiatowe</option><option value="SZTAB">SZTAB — duża akcja</option></select><div id="countyFields"><label>Województwo</label><select id="loginProvince"></select><label>Powiat</label><select id="loginCounty"></select></div>';
$('unit').previousElementSibling.before(wrap);
const unitLabel=$('unit').previousElementSibling;let counties=[],logins=[],requestId=0;
const qr=document.createElement('a');qr.href='./external-join.html';qr.textContent='Dołącz do zdarzenia kodem QR / 6-cyfrowym';qr.style.cssText='display:block;text-align:center;color:#93c5fd;margin-top:16px';$('loginBtn').after(qr);
document.querySelector('.brand small').textContent='Powiaty i sztaby — dostęp autoryzowany';
document.querySelector('.lock').textContent='Wybierz swój powiat i konto. Jednostka bez konta może szybko dołączyć do zdarzenia kodem QR otrzymanym od SK.';
async function directory(){
 const seq=++requestId;logins=[];$('unit').innerHTML='<option value="">Ładowanie kont…</option>';
 const {data,error}=await sb.rpc('firemap_county_logins',{p_county_id:$('loginCounty').value});if(seq!==requestId)return;
 if(error){$('unit').innerHTML='<option value="">Nie udało się pobrać kont</option>';return;}
 logins=data||[];renderAccounts();
}
function renderAccounts(){const role=$('countyRole').value,rows=logins.filter(a=>role==='SK'?a.role==='SK':['UNIT','JRG'].includes(a.role));$('unit').innerHTML='<option value="">Wybierz konto…</option>'+rows.map(a=>'<option value="'+esc(a.login_email)+'">'+esc(a.unit_name)+'</option>').join('');if(role==='SK'&&rows.length===1)$('unit').value=rows[0].login_email;}
function provinces(){const rows=counties.filter(c=>c.province===$('loginProvince').value);$('loginCounty').innerHTML=rows.map(c=>'<option value="'+c.id+'">'+esc(c.name)+'</option>').join('');if(rows.length)directory();else{$('unit').innerHTML='<option>Brak aktywnego SK</option>';logins=[];}}
$('loginProvince').onchange=provinces;$('loginCounty').onchange=directory;
$('countyRole').onchange=()=>{const hq=$('countyRole').value==='SZTAB';$('countyFields').hidden=hq;$('unit').hidden=hq;unitLabel.hidden=hq;$('sztabLoginFields').hidden=!hq;renderAccounts();};
async function verified(session){if(!session?.user?.id)return null;const{data,error}=await sb.from('firemap_accounts').select('role,unit_name,enabled,county_id,login_email').eq('user_id',session.user.id).maybeSingle();return !error&&data?.enabled?data:null;}
function route(a){localStorage.setItem('firemapVerifiedUnit',a.unit_name);localStorage.setItem('firemapVerifiedRole',a.role);location.replace(a.role==='SZTAB'?'./dispatcher.html?chooseArea=1':a.role==='SK'?'./dispatcher.html':'./index.html');}
async function login(){
 const role=$('countyRole').value,slug=$('sztabLoginId').value.trim().toLowerCase(),email=role==='SZTAB'?'sztab.'+slug+'@firemap.local':$('unit').value;
 if(!email||(role==='SZTAB'&&!/^[a-z0-9][a-z0-9-]{2,39}$/.test(slug))||!$('password').value){$('msg').textContent='Wybierz konto i wpisz hasło; dla sztabu podaj identyfikator.';return;}
 $('loginBtn').disabled=true;$('msg').textContent='Logowanie…';
 try{
  await sb.auth.signOut();const{data,error}=await sb.auth.signInWithPassword({email,password:$('password').value});if(error)throw Error('Nieprawidłowy login lub hasło.');
  const a=await verified(data.session);
  if(!a||(role==='SZTAB'?a.role!=='SZTAB':a.county_id!==$('loginCounty').value||(role==='SK'?a.role!=='SK':!['UNIT','JRG'].includes(a.role)))){await sb.auth.signOut();throw Error('Konto nie ma dostępu do wybranego powiatu/panelu.');}
  route(a);
 }catch(e){$('msg').textContent=e.message;}finally{$('loginBtn').disabled=false;}
}
$('loginBtn').onclick=login;$('password').addEventListener('keydown',e=>{if(e.key==='Enter')login();});
try{
 const{data,error}=await sb.from('firemap_counties').select('id,province,name').order('province').order('name');if(error)throw error;counties=data||[];
 $('loginProvince').innerHTML=[...new Set(counties.map(c=>c.province))].map(p=>'<option>'+esc(p)+'</option>').join('');provinces();
 const{data:session}=await sb.auth.getSession();if(session.session){const a=await verified(session.session);if(a)route(a);else await sb.auth.signOut();}
}catch{$('msg').textContent='Nie udało się pobrać powiatów. Odśwież stronę.';}
})();
