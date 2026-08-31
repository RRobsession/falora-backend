package com.rrlime.falora

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rrlime.falora/play_offers",
        ).setMethodCallHandler(PlayOfferPriceHandler(this))
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        configureSamsungKeyboardWindow()
        createNotificationChannel()
    }

    private fun configureSamsungKeyboardWindow() {
        if (!Build.MANUFACTURER.equals("samsung", ignoreCase = true)) return

        // Some Samsung One UI versions repeatedly dismiss the IME while a
        // Flutter activity is resized. Panning keeps the focused field visible
        // without recreating the Flutter viewport on every keyboard frame.
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            "falora_ready",
            "Falora Bildirimleri",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Fal ve çift uyumu hazır bildirimleri"
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
