package pl.firemap.zastep

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.google.android.gms.location.*

class LocationService:Service(){
 private lateinit var client:FusedLocationProviderClient
 private val cb=object:LocationCallback(){override fun onLocationResult(r:LocationResult){val l=r.lastLocation?:return;getSharedPreferences("gps",MODE_PRIVATE).edit().putLong("time",System.currentTimeMillis()).putLong("lat",java.lang.Double.doubleToRawLongBits(l.latitude)).putLong("lng",java.lang.Double.doubleToRawLongBits(l.longitude)).putFloat("accuracy",l.accuracy).apply()}}
 override fun onCreate(){super.onCreate();val ch="firemap_gps";(getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(NotificationChannel(ch,"FIREMAP GPS",NotificationManager.IMPORTANCE_LOW));val n=NotificationCompat.Builder(this,ch).setSmallIcon(android.R.drawable.ic_menu_mylocation).setContentTitle("FIREMAP Zastęp").setContentText("GPS działa w tle").setOngoing(true).build();ServiceCompat.startForeground(this,101,n,ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION);client=LocationServices.getFusedLocationProviderClient(this)}
 @android.annotation.SuppressLint("MissingPermission") override fun onStartCommand(i:Intent?,f:Int,id:Int):Int{val q=LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY,2000).setMinUpdateIntervalMillis(1000).setMinUpdateDistanceMeters(2f).build();client.requestLocationUpdates(q,cb,mainLooper);return START_STICKY}
 override fun onDestroy(){client.removeLocationUpdates(cb);super.onDestroy()}
 override fun onBind(i:Intent?):IBinder?=null
}
