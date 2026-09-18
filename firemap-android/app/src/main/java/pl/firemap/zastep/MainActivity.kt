package pl.firemap.zastep

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.webkit.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.ByteArrayInputStream

/** The same terminal code is bundled in the APK; no network is needed to open saved maps. */
class MainActivity : AppCompatActivity() {
 private lateinit var web: WebView
 private val base = "https://hj8kggdtv9-star.github.io/mapa-straz-radomsko/"
 private var pendingGeo: Pair<String, GeolocationPermissions.Callback>? = null
 private fun internal(u: Uri) = u.scheme == "https" && u.host == "hj8kggdtv9-star.github.io" && u.path?.startsWith("/mapa-straz-radomsko/") == true
 override fun onCreate(b: Bundle?) {
  super.onCreate(b)
  web = WebView(this); setContentView(web); setup()
  val incoming = intent?.data
  web.loadUrl(if (incoming != null && internal(incoming) && incoming.path?.endsWith("external-join.html") == true) incoming.toString() else base + "android-start.html")
 }
 @SuppressLint("SetJavaScriptEnabled") private fun setup() {
  web.settings.javaScriptEnabled = true
  web.settings.domStorageEnabled = true
  web.settings.allowFileAccess = false
  web.settings.allowContentAccess = false
  web.settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
  web.settings.setSupportMultipleWindows(false)
  web.settings.userAgentString += " FIREMAP-Android/1.1"
  web.webViewClient = object : WebViewClient() {
   override fun shouldOverrideUrlLoading(v: WebView?, r: WebResourceRequest?): Boolean {
    val u = r?.url ?: return true
    if (internal(u)) return false
    if (u.scheme in listOf("https", "http", "tel", "geo")) try {
     startActivity(Intent(if(u.scheme == "tel") Intent.ACTION_DIAL else Intent.ACTION_VIEW, u))
    } catch (_: Exception) { }
    return true
   }
   override fun shouldInterceptRequest(v: WebView?, r: WebResourceRequest?): WebResourceResponse? {
    val u = r?.url ?: return null
    if (!internal(u)) return null
    val path = u.path!!.removePrefix("/mapa-straz-radomsko/").ifEmpty { "android-start.html" }
    if (path.split('/').any { it == ".." } || path.contains('\\')) return missing()
    val mime = when (path.substringAfterLast('.')) { "html" -> "text/html"; "js" -> "application/javascript"; "css" -> "text/css"; "json" -> "application/json"; "png" -> "image/png"; "svg" -> "image/svg+xml"; "woff2" -> "font/woff2"; else -> "application/octet-stream" }
    return try { WebResourceResponse(mime, "UTF-8", assets.open("www/$path")) } catch (_: Exception) { missing() }
   }
  }
  web.webChromeClient = object : WebChromeClient() {
   override fun onGeolocationPermissionsShowPrompt(origin: String?, cb: GeolocationPermissions.Callback?) {
    if (origin == null || cb == null) return
    if (!origin.startsWith("https://hj8kggdtv9-star.github.io")) { cb.invoke(origin,false,false);return }
    if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) cb.invoke(origin,true,false)
    else { pendingGeo?.let { it.second.invoke(it.first,false,false) };pendingGeo=Pair(origin,cb);ActivityCompat.requestPermissions(this@MainActivity,arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION),7) }
   }
   override fun onJsConfirm(v: WebView?, url: String?, message: String?, result: JsResult?): Boolean {
    androidx.appcompat.app.AlertDialog.Builder(this@MainActivity).setMessage(message).setPositiveButton("Potwierdzam") { _,_ -> result?.confirm() }.setNegativeButton("Anuluj") { _,_ -> result?.cancel() }.setOnCancelListener { result?.cancel() }.show();return true
   }
  }
 }
 private fun missing() = WebResourceResponse("text/plain","UTF-8",404,"Not Found",emptyMap(),ByteArrayInputStream("Brak pliku w pakiecie aplikacji".toByteArray()))
 override fun onRequestPermissionsResult(code:Int,permissions:Array<out String>,results:IntArray) {
  super.onRequestPermissionsResult(code,permissions,results)
  if(code==7) { pendingGeo?.let { it.second.invoke(it.first,results.any { r -> r==PackageManager.PERMISSION_GRANTED },false) };pendingGeo=null }
 }
 @Deprecated("Android back compatibility") override fun onBackPressed() { if(web.canGoBack()) web.goBack() else super.onBackPressed() }
 override fun onDestroy() { pendingGeo?.let { it.second.invoke(it.first,false,false) };web.destroy();super.onDestroy() }
}
