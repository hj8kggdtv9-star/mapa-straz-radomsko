/* Reuse the existing tactical editor through token-scoped RPCs, never anonymous table writes. */
window.firemapGuestTacticalAdapter=function(sb,state,onExpired){
 let snapshot=null,loading=null;
 async function read(){if(loading)return loading;loading=(async()=>{const r=await sb.rpc('external_tactical_read',{p_session_token:state.session_token});if(r.error){if(r.error.message==='Sesja wygasła')onExpired();throw r.error}snapshot=r.data;return snapshot;})();try{return await loading}finally{loading=null}}
 function from(table){let action='read',rows=[],ids=[],filters=[];
  const q={select(){return q},eq(k,v){filters.push([k,v]);return q},in(k,v){if(action==='delete'&&k==='id')ids=v;return q},order(){return q},upsert(v){action='write';rows=v;return q},delete(){action='delete';return q},async then(resolve,reject){
   try{let result;if(action==='read'){const data=await read();result=table==='incidents'?[data.incident]:data.drawings;for(const[k,v]of filters)result=result.filter(x=>x[k]===v);}
    else{const r=await sb.rpc('external_tactical_write',{p_session_token:state.session_token,p_rows:rows,p_delete_ids:ids});if(r.error)throw r.error;result=r.data;}
    return resolve({data:result,error:null});
   }catch(error){return resolve({data:null,error})}
  }};return q;
 }
 return {from,channel(){const ch={on(){return ch},subscribe(){return ch}};return ch},read};
};
window.startFiremapGuestTactical=async function({map,sb,state,onExpired}){
 if(window.firemapGuestTacticalStarted)return;
 const adapter=window.firemapGuestTacticalAdapter(sb,state,onExpired);
 try{await adapter.read()}catch{return}
 window.firemapGuestTacticalStarted=true;window.firemapCtx={map,sb:adapter,session:{user:{id:state.session_id}},guest:true};
 const css=document.createElement('style');css.textContent='.kdr-main-btn{display:none!important}.tactical-main-btn{top:130px!important;width:auto!important}.tactical-sheet button,.tac-mini button,.tac-point-editor button{margin-top:0}.tac-mini button{width:auto}.tac-lock{top:185px!important}';document.head.appendChild(css);
 for(const src of ['tactical-ui-core.js','tactical-point-drag.js','tactical-sector-drag.js','tactical-sector-description.js','tactical-danger-radius.js','tactical-water-distance.js','tactical-shared-viewer.js']){const el=document.createElement('script');el.src=src+'?v=20260915-hq-1';el.async=false;document.head.appendChild(el)}
};
