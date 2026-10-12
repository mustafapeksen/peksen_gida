package com.example.peksen_gida

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger, "peksen/location/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { LocationTrackingService.sink = sink }
                override fun onCancel(arguments: Any?) { LocationTrackingService.sink = null }
            })
        MethodChannel(engine.dartExecutor.binaryMessenger, "peksen/location").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (pending != null) result.success(false)
                    else {
                        pending = result
                        val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                        if (Build.VERSION.SDK_INT >= 33) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                        if (permissions.any { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }) {
                            requestPermissions(permissions.toTypedArray(), 1201)
                        } else startTracking()
                    }
                }
                "stop" -> { stopService(Intent(this, LocationTrackingService::class.java)); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun startTracking() {
        val location = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val notification = Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        if (!location || !notification || isFinishing) { pending?.success(false); pending = null; return }
        try {
            val intent = Intent(this, LocationTrackingService::class.java)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
            pending?.success(true)
        } catch (_: Exception) { pending?.success(false) }
        pending = null
    }
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == 1201) startTracking()
    }
    override fun onDestroy() {
        stopService(Intent(this, LocationTrackingService::class.java))
        LocationTrackingService.sink = null
        pending?.success(false); pending = null
        super.onDestroy()
    }
}
