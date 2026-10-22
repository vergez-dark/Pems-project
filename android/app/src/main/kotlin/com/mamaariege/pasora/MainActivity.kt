package com.mamaariege.pasora

import android.app.KeyguardManager
import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pems.store/device_lock")
            .setMethodCallHandler { call, result ->
                if (call.method != "isReadyForBiometrics") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(!keyguard.isKeyguardLocked && power.isInteractive)
            }
    }
}
