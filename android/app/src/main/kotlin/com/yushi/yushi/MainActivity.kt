package com.yushi.yushi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.yushi.yushi/widget",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "refresh" -> {
                        TodayWidget.refresh(this)
                        result.success(null)
                    }
                    "pin" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        result.success(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(ComponentName(this, TodayWidget::class.java), null, null))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        TodayWidget.refresh(this)
    }

    override fun onResume() {
        super.onResume()
        TodayWidget.refresh(this)
        widgetChannel?.invokeMethod("reload", null)
    }
}
