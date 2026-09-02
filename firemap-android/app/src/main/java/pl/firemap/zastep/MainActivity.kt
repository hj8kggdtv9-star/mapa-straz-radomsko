package pl.firemap.zastep

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.webkit.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.*

class MainActivity: AppCompatActivity() {
 private lateinit var web: WebView
 private val io=Executors.newSingleThreadExecutor()
 private val base="https://hj8kggdtv9-star.github.io/mapa-straz-radomsko/"
 override fun onCreate(b:Bundle?){super.onCreate(b);web=WebView(this);setContentView(web);setup();requestLocation();web.loadUrl(base+"vehicle.html")}
 @SuppressLint("SetJavaScriptEnabled") private fun setup(){web.settings.javaScriptEnabled=true;web.settings.domStorageEnabled=true;web.settings.databaseEnabled=true;web.settings.cacheMode=WebSettings.LOAD_DEFAULT;web.settings.allowFileAccess=true;web.webViewClient=object:WebViewClient(){override fun shouldInterceptRequest(v:WebView?,r:WebResourceRequest?):WebResourceResponse?{val u=r?.url?.toString()?:return null;return OfflineStore.response(this@MainActivity,u)}};web.webChromeClient=WebChromeClient();web.addJavascriptInterface(Bridge(),"FiremapAndroid")}
 private fun requestLocation(){val p=Manifest.permission.ACCESS_FINE_LOCATION;if(ContextCompat.checkSelfPermission(this,p)!=PackageManager.PERMISSION_GRANTED)ActivityCompat.requestPermissions(this,arrayOf(p),7)}
 inner class Bridge{
  @JavascriptInterface fun isNative()=true
  @JavascriptInterface fun startGps(){runOnUiThread{ContextCompat.startForegroundService(this@MainActivity,Intent(this@MainActivity,LocationService::class.java))}}
  @JavascriptInterface fun stopGps(){stopService(Intent(this@MainActivity,LocationService::class.java))}
  @JavascriptInterface fun downloadMap(name:String,south:Double,west:Double,north:Double,east:Double,minZoom:Int,maxZoom:Int,layers:String):String{io.execute{OfflineStore.download(this@MainActivity,name,south,west,north,east,minZoom,maxZoom,layers.split(',')){p,msg->runOnUiThread{web.evaluateJavascript("window.firemapOfflineProgress&&window.firemapOfflineProgress(${p},${js(msg)})",null)}}};return "STARTED"}
  @JavascriptInterface fun listMaps()=OfflineStore.list(this@MainActivity)
  @JavascriptInterface fun deleteMap(name:String)=OfflineStore.delete(this@MainActivity,name)
 }
 private fun js(s:String)="'"+s.replace("\\","\\\\").replace("'","\\'")+"'"
}

object OfflineStore{
 private fun root(c:android.content.Context)=File(c.filesDir,"offline_maps").apply{mkdirs()}
 fun list(c:android.content.Context)=root(c).listFiles()?.filter{it.isDirectory}?.joinToString("|"){it.name}.orEmpty()
 fun delete(c:android.content.Context,n:String):Boolean=File(root(c),safe(n)).deleteRecursively()
 fun response(c:android.content.Context,url:String):WebResourceResponse?{val f=fileFor(c,url)?:return null;if(!f.exists())return null;val mime=if(f.extension=="png")"image/png" else "image/jpeg";return WebResourceResponse(mime,null,f.inputStream())}
 private fun safe(s:String)=s.replace(Regex("[^A-Za-z0-9._-]"),"_")
 private fun fileFor(c:android.content.Context,u:String):File?{val uri=android.net.Uri.parse(u);val host=uri.host?:return null;val p=uri.pathSegments;val key=when{
  host.contains("openstreetmap.org")&&p.size>=3 -> "OSM/${p[p.size-3]}/${p[p.size-2]}/${p.last().substringBefore('.')}.png"
  host.contains("mapserver.bdl.lasy.gov.pl")&&p.contains("tile")&&p.size>=3 -> {val i=p.indexOfLast{it=="tile"};if(i+3<p.size)"BDL/${p[i+1]}/${p[i+3]}/${p[i+2]}.png" else null}
  else->null}?:return null;for(d in root(c).listFiles().orEmpty())File(d,key).let{if(it.exists())return it};return null}
 fun download(c:android.content.Context,name:String,s:Double,w:Double,n:Double,e:Double,z0:Int,z1:Int,layers:List<String>,cb:(Int,String)->Unit){val dir=File(root(c),safe(name)).apply{mkdirs()};var done=0;val jobs=mutableListOf<Triple<String,String,File>>();for(z in z0..z1){val x0=lonX(w,z);val x1=lonX(e,z);val y0=latY(n,z);val y1=latY(s,z);for(x in x0..x1)for(y in y0..y1){if("OSM" in layers)jobs+=Triple("OSM","https://tile.openstreetmap.org/$z/$x/$y.png",File(dir,"OSM/$z/$x/$y.png"));if("BDL" in layers)jobs+=Triple("BDL","https://mapserver.bdl.lasy.gov.pl/arcgis/rest/services/WMTS_BDL/MapServer/tile/$z/$y/$x",File(dir,"BDL/$z/$x/$y.png"));if("FIRE" in layers)jobs+=Triple("FIRE","https://mapserver.bdl.lasy.gov.pl/arcgis/rest/services/Mobile/Mapa_dojazdy_pozarowe_mBDL/MapServer/tile/$z/$y/$x",File(dir,"FIRE/$z/$x/$y.png"))}}
  jobs.forEach{(_,u,f)->try{f.parentFile?.mkdirs();URL(u).openConnection().apply{connectTimeout=10000;readTimeout=15000;setRequestProperty("User-Agent","FIREMAP-Zastep/0.1")}.getInputStream().use{input->f.outputStream().use{input.copyTo(it)}}}catch(_:Exception){};done++;if(done%10==0||done==jobs.size)cb(if(jobs.isEmpty())100 else done*100/jobs.size,"Pobrano $done/${jobs.size}")};File(dir,"meta.txt").writeText("$s,$w,$n,$e,$z0,$z1,${layers.joinToString()}");cb(100,"Mapa offline gotowa")}
 private fun lonX(l:Double,z:Int)=floor((l+180.0)/360.0*(1 shl z)).toInt()
 private fun latY(lat:Double,z:Int):Int{val r=Math.toRadians(lat.coerceIn(-85.0511,85.0511));return floor((1.0-ln(tan(r)+1/cos(r))/Math.PI)/2.0*(1 shl z)).toInt()}
}
