(()=>{
const dbp=new Promise((resolve,reject)=>{const r=indexedDB.open('firemap-offline-v1',1);r.onupgradeneeded=()=>r.result.createObjectStore('packs',{keyPath:'id'});r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
async function tx(mode,fn){const db=await dbp;return new Promise((resolve,reject)=>{const t=db.transaction('packs',mode),r=fn(t.objectStore('packs'));t.oncomplete=()=>resolve(r.result);t.onerror=()=>reject(t.error);t.onabort=()=>reject(t.error||Error('Zapis przerwany'))})}
const owner=()=>localStorage.getItem('firemapOfflineOwner');
window.firemapOfflineStore={all:async()=>((await tx('readonly',s=>s.getAll()))||[]).filter(p=>p.owner===owner()&&Date.parse(p.expiresAt)>Date.now()),put:p=>tx('readwrite',s=>s.put(p)),remove:id=>tx('readwrite',s=>s.delete(id)),owner};
})();
