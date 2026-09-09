(()=>{
if(window.__firemapSztabAdmin)return;window.__firemapSztabAdmin=true;
async function init(){
 const c=window.firemapSkCtx;if(!c?.sb)return setTimeout(init,200);
 const {data}=await c.sb.auth.getSession();if(!data.session)return;
 const {data:a}=await c.sb.from('firemap_accounts').select('role,enabled').eq('user_id',data.session.user.id).maybeSingle();
 if(!a?.enabled||a.role!=='SK'||document.getElementById('sztabAdmin'))return;
 const card=document.createElement('details');card.id='sztabAdmin';card.className='card';
 card.innerHTML='<summary style="cursor:pointer;font-weight:800">Utwórz konto SZTABU</summary><p class="hint">Osobny panel dla dużej akcji. Przekaż obsadzie identyfikator i hasło. Zastępy dołączą kodem QR zdarzenia.</p><label>Nazwa sztabu<input id="sztabName" maxlength="100" placeholder="np. Pożar lasu — sztab"></label><label>Identyfikator logowania<input id="sztabSlug" maxlength="40" autocapitalize="none" placeholder="np. las-2026"></label><label>Hasło sztabu<input id="sztabPass" type="password" autocomplete="new-password" minlength="12" maxlength="128" placeholder="Minimum 12 znaków"></label><button class="fireBtn" id="sztabCreate">Utwórz sztab</button><div class="state" id="sztabState" role="status"></div>';
 document.querySelector('.panel').insertBefore(card,document.getElementById('logout'));
 card.querySelector('#sztabCreate').onclick=async()=>{
  const button=card.querySelector('#sztabCreate'),state=card.querySelector('#sztabState'),pass=card.querySelector('#sztabPass');
  const slug=card.querySelector('#sztabSlug').value.trim().toLowerCase(),name=card.querySelector('#sztabName').value.trim();
  if(!/^[a-z0-9][a-z0-9-]{2,39}$/.test(slug)||name.length<3||pass.value.length<12){state.textContent='Podaj nazwę, identyfikator (3–40 małych liter, cyfr lub myślników) i hasło o długości co najmniej 12 znaków.';return;}
  button.disabled=true;state.textContent='Tworzę konto…';
  try{
   const {data,error}=await c.sb.functions.invoke('create-sztab',{body:{slug,name,password:pass.value}});
   if(error){let detail;try{detail=await error.context.json()}catch{}throw new Error(detail?.error||'Nie udało się utworzyć konta. Sprawdź połączenie.');}
   if(data?.error)throw new Error(data.error);
   pass.value='';state.textContent='Utworzono: '+data.name+'. Logowanie: wybierz SZTAB, identyfikator '+data.slug+' i ustawione hasło.';
  }catch(e){state.textContent=e.message;}finally{button.disabled=false;}
 };
}
function wait(){if(!window.firemapSkCtx?.sb)return setTimeout(wait,200);init();window.firemapSkCtx.sb.auth.onAuthStateChange(()=>setTimeout(init,0));}
wait();
})();
