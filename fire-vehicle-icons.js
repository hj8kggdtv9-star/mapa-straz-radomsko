(()=>{if(window.__firemapVehicleStatusIconsV4)return;window.__firemapVehicleStatusIconsV4=true;const s=document.createElement('style');s.textContent=`
.vehicleIcon:not(.kdrOwn),.ownVehicle:not(.kdrOwn){border-color:#fff!important;font-size:20px!important}
.vehicleIcon:not(.kdrOwn)::before,.ownVehicle:not(.kdrOwn)::before{content:none!important;display:none!important}
.ownVehicle:not(.kdrOwn) .call{font-size:9px!important}
.vehicleIcon.pulseA,.ownVehicle.pulseA{background:#f59e0b!important}
.vehicleIcon.pulseR,.ownVehicle.pulseR{background:#dc2626!important}
.vehicleIcon.pulseB,.ownVehicle.pulseB{background:#2563eb!important}
.vehicleIcon:not(.pulseA):not(.pulseR):not(.pulseB):not(.kdrOwn),.ownVehicle:not(.pulseA):not(.pulseR):not(.pulseB):not(.kdrOwn){background:#64748b!important}
.kdrOwn{background:#ca8a04!important}
`;document.head.appendChild(s)})();