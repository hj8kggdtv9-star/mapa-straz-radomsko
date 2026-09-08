(()=>{if(window.__firemapSkLocationPresetsV1)return;window.__firemapSkLocationPresetsV1=true;
function wait(){if(!window.firemapSkCtx||!document.getElementById('address')||!document.getElementById('useCoords'))return setTimeout(wait,250);init()}
async function init(){
 const address=document.getElementById('address'),useCoords=document.getElementById('useCoords'),coords=document.getElementById('coords'),state=document.getElementById('searchState');
 const wrap=document.createElement('div');wrap.id='fmCountyPlaceWrap';wrap.style.margin='8px 0 6px';wrap.innerHTML='<div class="sectionLabel" style="margin-top:0">Szybki wybór miejscowości powiatu</div><select id="fmCountyPlace" style="width:100%;min-height:43px;border-radius:10px;background:#091525;border:1px solid #475569;color:#fff;padding:0 10px;font-size:14px;margin-top:6px"><option value="">— wybierz miejscowość alfabetycznie —</option></select><div class="hint" id="fmCountyPlaceHint">Wybór ustawi miejscowość na mapie. Dokładny adres możesz dopisać później.</div>';
 address.parentNode.insertBefore(wrap,address);
 const sel=wrap.querySelector('#fmCountyPlace');
 let places=['Radomsko'];
 try{const r=await fetch('./firemap_units.json',{cache:'no-store'}),j=await r.json();for(const u of(j.units||[])){const n=String(u.name||'').replace(/^OSP\s+/i,'').trim();if(n)places.push(n)}}catch(e){console.warn('FIREMAP SK miejscowości',e)}
 places=[...new Set(places)].sort((a,b)=>a.localeCompare(b,'pl',{sensitivity:'base'}));
 sel.innerHTML='<option value="">— wybierz miejscowość alfabetycznie —</option>'+places.map(p=>`<option value="${escAttr(p)}">${esc(p)}</option>`).join('');
 sel.onchange=async()=>{const place=sel.value;if(!place)return;sel.disabled=true;if(state)state.textContent='Ustawiam miejscowość…';try{const q=`${place}, powiat radomszczański, łódzkie, Polska`,r=await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&countrycodes=pl&accept-language=pl&q=${encodeURIComponent(q)}`),d=await r.json();let x=(d||[]).find(v=>/radomszcz/i.test(String(v.display_name||'')))||(d||[])[0];if(!x)throw new Error('Nie znaleziono miejscowości');address.value=place;coords.value=`${(+x.lon).toFixed(14)};${(+x.lat).toFixed(14)}`;useCoords.click();if(state)state.textContent=`Wybrano: ${place}`}catch(e){if(state)state.textContent='Nie udało się ustawić miejscowości — użyj wyszukiwarki adresu.'}finally{sel.disabled=false}};
}
function esc(s){return String(s||'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}
function escAttr(s){return esc(s)}
wait();})();
