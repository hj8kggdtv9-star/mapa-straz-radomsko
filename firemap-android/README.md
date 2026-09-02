# FIREMAP Zastęp Android

Native Android shell for FIREMAP Zastęp with foreground GPS and offline map storage.

## Implemented in v0.1
- Existing FIREMAP vehicle UI runs inside Android WebView.
- Foreground high-accuracy GPS service scaffold.
- Native JS bridge for starting/stopping GPS.
- Offline region downloader scaffold for OSM, BDL base and BDL fire-road raster tiles.
- Local offline tile interception for OSM/BDL when files are present.

## Required before production APK
1. Add in-app offline-map UI to select rectangle/current viewport, name it, choose layers and zoom range.
2. Add K-GESUT hydrant offline export/cache. Current hydrants are WMS images and need a bounded WMS tile-cache implementation or a permitted vector source; do not claim hydrants work offline yet.
3. Correctly distinguish BDL base vs fire-road cache paths in request interception.
4. Connect foreground-service GPS samples back to the FIREMAP/Supabase position publisher when WebView is backgrounded. Current service records latest GPS locally; it does not yet publish to Supabase by itself.
5. Implement Android 11+ staged background-location permission flow and Android 13+ notification permission.
6. Add storage estimates/limits and cancellation for offline downloads.
7. Verify source-provider terms/caching policy before distributing downloaded map data.
8. Add signed release configuration and CI workflow to build APK/AAB.

## Test checklist
- Gradle assembleDebug succeeds.
- Login/session persists after app restart.
- Vehicle status, KDR, tactical layers and assignments match web FIREMAP.
- GPS notification remains visible after screen off; test Android 10/11/12/13/14/15.
- No duplicate GPS publishers.
- Download a small region, enable airplane mode, restart app and verify every requested zoom/layer.
- Delete an offline region and verify storage is reclaimed.
- Corrupt/partial download fails gracefully.
- Hydrant and BDL attribution remains visible.

This directory is an engineering prototype until all items above pass on a real Android device.
