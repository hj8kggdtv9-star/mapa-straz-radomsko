(()=>{if(window.__firemapVehicleStatusIconsV5)return;window.__firemapVehicleStatusIconsV5=true;const s=document.createElement('style');s.textContent=`
.vehicleIcon:not(.kdrOwn),.ownVehicle:not(.kdrOwn){border-color:#fff!important;font-size:20px!important}
.vehicleIcon:not(.kdrOwn)::before,.ownVehicle:not(.kdrOwn)::before{content:none!important;display:none!important}
.ownVehicle:not(.kdrOwn) .call{font-size:9px!important}
.vehicleIcon.pulseA,.ownVehicle.pulseA,.vehicleIcon.pulseAmber,.ownVehicle.pulseAmber{background:#f59e0b!important}
.vehicleIcon.pulseR,.ownVehicle.pulseR,.vehicleIcon.pulseRed,.ownVehicle.pulseRed{background:#dc2626!important}
.vehicleIcon.pulseB,.ownVehicle.pulseB,.vehicleIcon.pulseBlue,.ownVehicle.pulseBlue{background:#2563eb!important}
.vehicleIcon:not(.pulseA):not(.pulseR):not(.pulseB):not(.pulseAmber):not(.pulseRed):not(.pulseBlue):not(.kdrOwn),.ownVehicle:not(.pulseA):not(.pulseR):not(.pulseB):not(.pulseAmber):not(.pulseRed):not(.pulseBlue):not(.kdrOwn){background:#64748b!important}
.kdrOwn,.vehicleIcon.kdrOwn,.ownVehicle.kdrOwn{background:#ca8a04!important}
`;document.head.appendChild(s)})();