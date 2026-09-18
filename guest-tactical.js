/* Reuse the existing tactical editor through token-scoped RPCs, never anonymous table writes. */
window.firemapGuestTacticalAdapter=function(sb,state,onExpired){
 let snapshot=null,loading=null;
 async function read(){if(loading)return loading;loading=(async()=>{const r=await sb.rpc('external_tactical_read',{p_session_token:state.session_token});if(r.error){if(r.error.message==='Sesja wygasła')onExpired();throw r.error}snapshot=r.data;return snapshot;})();try{return await loading}finally{loading=null}}
 function from(table){let action='read',rows=[],ids=[],filters=[];
  const q={select(){return q},eq(k,v){filters.push([k,v]);return q},in(k,v){if(action==='delete'&&k==='id')ids=v;return q},order(){return q},upsert(v){action='write';rows=v;return q},delete(){action='delete';return q},async then(resolve,reject){
   try{let result;if(action==='read'){const data=await read();result=table==='incidents'?[data.incident]:data.drawings;for(const[k,v]of filters)result=result.filter(x=>x[k]===v);}
    else{throw new Error('Zastęp po QR ma dostęp do odczytu TAKTYKI KDR.');}
    return resolve({data:result,error:null});
   }catch(error){return resolve({data:null,error})}
  }};return q;
 }
 return {from,channel(){const ch={on(){return ch},subscribe(){return ch}};return ch},read};
};
// Mount tools independently of the first network response. The editor reports RPC errors.
const firemapGuestScripts=new Map();
function loadFiremapGuestScript(src){
 if(firemapGuestScripts.has(src))return firemapGuestScripts.get(src);
 const task=new Promise((resolve,reject)=>{const el=document.createElement('script');el.src=src+'?v=20260918-symbols-1';el.async=false;el.onload=resolve;el.onerror=()=>{el.remove();reject(new Error('Nie pobrano '+src))};document.head.appendChild(el)});
 firemapGuestScripts.set(src,task);task.catch(()=>firemapGuestScripts.delete(src));return task;
}
window.startFiremapGuestTactical=function({map,sb,state,onExpired}){
 if(window.firemapGuestToolsLoading)return window.firemapGuestToolsLoading;
 if(window.firemapGuestTacticalStarted)return Promise.resolve();
 window.firemapCtx={map,sb:window.firemapGuestTacticalAdapter(sb,state,onExpired),session:{user:{id:state.session_id}},guest:true};
 const notice=document.getElementById('guestToolsState');
 if(notice){notice.hidden=false;notice.textContent='Ładowanie narzędzi mapy…'}
 const task=(async()=>{
  // Layers do not need a database request or a working tactical editor.
  const layers=loadFiremapGuestScript('forest-map-layers.js');
  const tactics=(async()=>{for(const src of ['tactical-shared-viewer.js','tactical-water-distance.js'])await loadFiremapGuestScript(src)})();
  const results=await Promise.allSettled([layers,tactics]);
  if(results.some(r=>r.status==='rejected')){if(notice){notice.textContent='Nie pobrano wszystkich narzędzi. Dotknij, aby ponowić.';notice.onclick=()=>window.startFiremapGuestTactical({map,sb,state,onExpired})}return}
  window.firemapGuestTacticalStarted=true;if(notice)notice.hidden=true;
 })();
 window.firemapGuestToolsLoading=task;return task.finally(()=>{window.firemapGuestToolsLoading=null});
};
