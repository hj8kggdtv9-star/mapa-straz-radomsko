# FIREMAP Zastęp Android 1.1 pilot

The APK bundles the current terminal, QR terminal and local offline viewer. Build with JDK 17, Gradle 8.11.1 and Android SDK 36:

```
python3 scripts/bundle_web.py
gradle :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

The Android APK workflow performs these steps and uploads `FIREMAP-Zastep-debug-apk`.

See [Android/offline/help acceptance](../ANDROID-OFFLINE-HELP.md) for implemented features, offline limits, signing and physical-device tests. The previous unconnected foreground-GPS scaffold and unauthorized OSM tile bulk downloader were removed. No privileged JavaScript bridge or unrestricted WebView file access remains.
