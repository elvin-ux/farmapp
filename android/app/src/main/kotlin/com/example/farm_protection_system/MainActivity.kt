package com.example.farm_protection_system

import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // Dismiss the Android 12 splash screen the instant Flutter
        // draws its first frame — no lingering icon or background.
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
