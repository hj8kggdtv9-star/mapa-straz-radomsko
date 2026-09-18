(()=>{
function normalize(value){const raw=String(value??'').trim();if(!raw)return null;if(!/^[+\d\s()-]+$/.test(raw))throw Error('Podaj poprawny numer telefonu (7–15 cyfr, opcjonalnie + na początku).');const n=raw.replace(/[\s()-]/g,'');if(!/^\+?\d{7,15}$/.test(n))throw Error('Podaj poprawny numer telefonu (7–15 cyfr, opcjonalnie + na początku).');return n;}
function popup(value){let n;try{n=normalize(value)}catch{return ''}return n?`<br><a class="firemap-call" href="tel:${n}" style="display:inline-block;padding:10px 12px;margin-top:6px;background:#166534;color:white;border-radius:8px;text-decoration:none">📞 Zadzwoń: ${n}</a>`:'';}
window.firemapContact={normalize,popup};
})();
