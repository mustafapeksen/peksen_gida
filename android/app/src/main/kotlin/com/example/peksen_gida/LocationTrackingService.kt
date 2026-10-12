package com.example.peksen_gida

import android.Manifest
import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.location.*
import android.os.*
import io.flutter.plugin.common.EventChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Visible, user-started foreground service. No boot start, storage or offline queue. */
class LocationTrackingService : Service(), LocationListener {
    companion object { var sink: EventChannel.EventSink? = null }
    private lateinit var locations: LocationManager
    private var lastSent = 0L
    private val handler = Handler(Looper.getMainLooper())
    private val health = object : Runnable {
        override fun run() {
            if (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                emit("permission_denied"); stopSelf(); return
            }
            if (!locations.isProviderEnabled(LocationManager.GPS_PROVIDER) && !locations.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) emit("gps_disabled")
            handler.postDelayed(this, 15000)
        }
    }
    private fun emit(status: String) { sink?.success(mapOf("tracking_status" to status)) }
    override fun onCreate() {
        super.onCreate()
        locations = getSystemService(LOCATION_SERVICE) as LocationManager
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("delivery_location", "Teslimat konumu", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, LocationTrackingService::class.java).setAction("STOP"), PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "delivery_location") else Notification.Builder(this)
        startForeground(1201, builder.setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Pekşen Gıda: konum paylaşılıyor")
            .setContentText("Yalnız aktif teslimat için. Durdurabilirsiniz.")
            .setContentIntent(open).setOngoing(true).addAction(android.R.drawable.ic_media_pause, "Durdur", stop).build())
        try {
            val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (fine && locations.allProviders.contains(LocationManager.GPS_PROVIDER)) locations.requestLocationUpdates(LocationManager.GPS_PROVIDER, 15000L, 0f, this)
            if (locations.allProviders.contains(LocationManager.NETWORK_PROVIDER)) locations.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 15000L, 0f, this)
            handler.post(health)
        } catch (_: SecurityException) { emit("permission_denied"); stopSelf() }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") { emit("stopped"); stopSelf() }
        return START_NOT_STICKY
    }
    override fun onLocationChanged(location: Location) {
        val now = SystemClock.elapsedRealtime()
        // Never use getLastKnownLocation; discard old fixes and throttle providers together.
        if (now - location.elapsedRealtimeNanos / 1000000 > 15000 || now - lastSent < 15000) return
        lastSent = now
        sink?.success(mapOf("tracking_status" to "live", "latitude" to location.latitude,
            "longitude" to location.longitude, "accuracy" to location.accuracy.toDouble(),
            "sampled_at" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(Date(location.time))))
    }
    override fun onProviderDisabled(provider: String) { emit("gps_disabled") }
    override fun onProviderEnabled(provider: String) { /* Next fresh fix resumes. */ }
    @Deprecated("Legacy listener callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) { }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onTaskRemoved(intent: Intent?) { stopSelf() }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        locations.removeUpdates(this)
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
