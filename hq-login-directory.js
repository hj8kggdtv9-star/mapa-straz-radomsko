(async()=>{
 const input=document.getElementById('sztabLoginId');if(!input)return;
 const select=document.createElement('select');select.id='hqLoginDirectory';select.style.cssText='width:100%;min-height:44px;background:#111e30;color:white;border:1px solid #475569;border-radius:10px;margin:8px 0';select.setAttribute('aria-label','Wybierz konto sztabu');
 select.add(new Option('Wybierz SZTAB lub wpisz identyfikator…',''));input.before(select);
 const sb=supabase.createClient('https://vqgipvwcvbhabvfipodl.supabase.co','sb_publishable_BYEVImorGhltw1aCaRXyRQ_pM2hKMkI');
 const {data,error}=await sb.rpc('firemap_sztab_logins');if(!error)for(const a of data||[])select.add(new Option(a.unit_name,a.login_email.replace(/^sztab\./,'').replace(/@firemap\.local$/,'')));
 select.onchange=()=>{input.value=select.value};input.addEventListener('input',()=>{select.value=''})
 const mode=document.getElementById('accessMode');if(mode){const sync=()=>{select.hidden=mode.value!=='SZTAB'||mode.disabled};mode.addEventListener('change',sync);new MutationObserver(sync).observe(mode,{attributes:true,attributeFilter:['disabled']});sync();}
})();
