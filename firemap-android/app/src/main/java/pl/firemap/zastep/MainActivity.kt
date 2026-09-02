package pl.firemap.zastep

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.webkit.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.ByteArrayInputStream
import java.io.File
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.*

class MainActivity:AppCompatActivity(){
 private lateinit var web:WebView;private val io=Executors.newSingleThreadExecutor();private val base="https://hj8kggdtv9-star.github.io/mapa-straz-radomsko/"
 override fun onCreate(b:Bundle?){super.onCreate(b);web=WebView(this);setContentView(web);setup();requestPermissions();web.loadUrl(base+"index.html")}
 @SuppressLint("SetJavaScriptEnabled") private fun setup(){web.settings.javaScriptEnabled=true;web.settings.domStorageEnabled=true;web.settings.databaseEnabled=true;web.settings.cacheMode=WebSettings.LOAD_CACHE_ELSE_NETWORK;web.settings.allowFileAccess=true;web.settings.mediaPlaybackRequiresUserGesture=false;web.webViewClient=object:WebViewClient(){override fun shouldInterceptRequest(v:WebView?,r:WebResourceRequest?):WebResourceResponse?=OfflineStore.response(this@MainActivity,r?.url?.toString()?:return null)};web.webChromeClient=object:WebChromeClient(){override fun onGeolocationPermissionsShowPrompt(origin:String?,cb:GeolocationPermissions.Callback?){if(ContextCompat.checkSelfPermission(this@MainActivity,Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)cb?.invoke(origin,true,false)else{requestPermissions();cb?.invoke(origin,false,false)}}};web.addJavascriptInterface(Bridge(),"FiremapAndroid")}
 private fun requestPermissions(){val q=mutableListOf<String>();if(ContextCompat.checkSelfPermission(this,Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED)q+=Manifest.permission.ACCESS_FINE_LOCATION;if(Build.VERSION.SDK_INT>=33&&ContextCompat.checkSelfPermission(this,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)q+=Manifest.permission.POST_NOTIFICATIONS;if(q.isNotEmpty())ActivityCompat.requestPermissions(this,q.toTypedArray(),7)}
 inner class Bridge{
  @JavascriptInterface fun isNative()=true
  @JavascriptInterface fun startGps(){runOnUiThread{if(ContextCompat.checkSelfPermission(this@MainActivity,Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)ContextCompat.startForegroundService(this@MainActivity,Intent(this@MainActivity,LocationService::class.java))else requestPermissions()}}
  @JavascriptInterface fun stopGps(){stopService(Intent(this@MainActivity,LocationService::class.java))}
  @JavascriptInterface fun estimateTiles(s:Double,w:Double,n:Double,e:Double,z0:Int,z1:Int,layers:String)=OfflineStore.estimate(s,w,n,e,z0,z1,layers.split(','))
  @JavascriptInterface fun downloadMap(name:String,s:Double,w:Double,n:Double,e:Double,z0:Int,z1:Int,layers:String):String{io.execute{OfflineStore.download(this@MainActivity,name,s,w,n,e,z0,z1,layers.split(',')){p,msg->runOnUiThread{web.evaluateJavascript("window.firemapOfflineProgress&&window.firemapOfflineProgress($p,${js(msg)})",null)}}};return "STARTED"}
  @JavascriptInterface fun listMaps()=OfflineStore.list(this@MainActivity)
  @JavascriptInterface fun deleteMap(name:String)=OfflineStore.delete(this@MainActivity,name)
 }
 private fun js(s:String)="'"+s.replace("\\","\\\\").replace("'","\\'")+"'"
 override fun onBackPressed(){if(web.canGoBack())web.goBack() else super.onBackPressed()}
}

object OfflineStore{
 private fun root(c:android.content.Context)=File(c.filesDir,"offline_maps").apply{mkdirs()};private fun safe(s:String)=s.replace(Regex("[^A-Za-z0-9._-]"),"_")
 fun list(c:android.content.Context)=root(c).listFiles()?.filter{it.isDirectory}?.joinToString("|"){it.name}.orEmpty();fun delete(c:android.content.Context,n:String)=File(root(c),safe(n)).deleteRecursively()
 fun estimate(s:Double,w:Double,n:Double,e:Double,z0:Int,z1:Int,layers:List<String>):Int{var k=0L;for(z in z0..z1){val nx=(lonX(e,z)-lonX(w,z)+1).coerceAtLeast(0);val ny=(latY(s,z)-latY(n,z)+1).coerceAtLeast(0);k+=nx.toLong()*ny*layers.count{it.isNotBlank()}};return k.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()}
 fun response(c:android.content.Context,u:String):WebResourceResponse?{val uri=android.net.Uri.parse(u);val host=uri.host?:return null;val p=uri.pathSegments;val key=when{host=="offline.firemap.local"&&p.size>=4->"${p[0]}/${p[1]}/${p[2]}/${p[3].substringBefore('.')}.png";host.contains("openstreetmap.org")&&p.size>=3->"OSM/${p[p.size-3]}/${p[p.size-2]}/${p.last().substringBefore('.')}.png";host.contains("mapserver.bdl.lasy.gov.pl")&&p.contains("tile")-> {val i=p.indexOfLast{it=="tile"};if(i+3<p.size){val layer=if(u.contains("Mapa_dojazdy_pozarowe"))"FIRE" else "BDL";"$layer/${p[i+1]}/${p[i+3]}/${p[i+2]}.png"}else null};else->null}?:return null;for(d in root(c).listFiles().orEmpty()){val f=File(d,key);if(f.exists())return WebResourceResponse("image/png",null,f.inputStream())};if(host=="offline.firemap.local"&&p.firstOrNull()=="HYDRANTS"&&p.size>=4)return try{val z=p[1].toInt();val x=p[2].toInt();val y=p[3].substringBefore('.').toInt();val bytes=URL(hydrantUrl(z,x,y)).openConnection().apply{connectTimeout=7000;readTimeout=10000}.getInputStream().readBytes();WebResourceResponse("image/png",null,ByteArrayInputStream(bytes))}catch(_:Exception){WebResourceResponse("image/png",null,ByteArrayInputStream(ByteArray(0)))};return null}
 fun download(c:android.content.Context,name:String,s:Double,w:Double,n:Double,e:Double,z0:Int,z1:Int,layers:List<String>,cb:(Int,String)->Unit){val dir=File(root(c),safe(name)).apply{mkdirs()};val jobs=mutableListOf<Pair<String,File>>();for(z in z0..z1)for(x in lonX(w,z)..lonX(e,z))for(y in latY(n,z)..latY(s,z)){if("OSM" in layers)jobs+="https://tile.openstreetmap.org/$z/$x/$y.png" to File(dir,"OSM/$z/$x/$y.png");if("BDL" in layers)jobs+="https://mapserver.bdl.lasy.gov.pl/arcgis/rest/services/WMTS_BDL/MapServer/tile/$z/$y/$x" to File(dir,"BDL/$z/$x/$y.png");if("FIRE" in layers)jobs+="https://mapserver.bdl.lasy.gov.pl/arcgis/rest/services/Mobile/Mapa_dojazdy_pozarowe_mBDL/MapServer/tile/$z/$y/$x" to File(dir,"FIRE/$z/$x/$y.png");if("HYDRANTS" in layers)jobs+=hydrantUrl(z,x,y) to File(dir,"HYDRANTS/$z/$x/$y.png")};var ok=0;jobs.forEachIndexed{i,(u,f)->try{f.parentFile?.mkdirs();URL(u).openConnection().apply{connectTimeout=10000;readTimeout=15000;setRequestProperty("User-Agent","FIREMAP-Zastep/1.0")}.getInputStream().use{a->f.outputStream().use{a.copyTo(it)}};ok++}catch(_:Exception){};if(i%8==0||i==jobs.lastIndex)cb(if(jobs.isEmpty())100 else (i+1)*100/jobs.size,"Pobrano ${i+1}/${jobs.size} · poprawne $ok")};File(dir,"meta.txt").writeText("$s,$w,$n,$e,$z0,$z1,${layers.joinToString()}");cb(100,"Mapa offline gotowa · $ok/${jobs.size} kafelków")}
 private fun hydrantUrl(z:Int,x:Int,y:Int):String{val a=merc(x,y,z);val b=merc(x+1,y+1,z);return "https://mapy.geoportal.gov.pl/wss/geosrv/MapServer_KGESUT_WMS/wms?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0&LAYERS=hydranty&STYLES=&FORMAT=image/png&TRANSPARENT=true&WIDTH=256&HEIGHT=256&CRS=EPSG:3857&BBOX=${a.first},${b.second},${b.first},${a.second}"}
 private fun merc(x:Int,y:Int,z:Int):Pair<Double,Double>{val n=(1 shl z).toDouble();val lon=x/n*360.0-180.0;val lat=Math.toDegrees(atan(sinh(Math.PI*(1-2*y/n))));val r=6378137.0;return r*Math.toRadians(lon) to r*ln(tan(Math.PI/4+Math.toRadians(lat)/2))}
 private fun lonX(l:Double,z:Int)=floor((l+180)/360*(1 shl z)).toInt();private fun latY(lat:Double,z:Int):Int{val r=Math.toRadians(lat.coerceIn(-85.0511,85.0511));return floor((1-ln(tan(r)+1/cos(r))/Math.PI)/2*(1 shl z)).toInt()}
}
