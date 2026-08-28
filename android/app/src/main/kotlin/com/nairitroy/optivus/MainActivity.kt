package com.nairitroy.optivus

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.nairitroy.optivus/notification_intent"
    private val EMAIL_LAUNCHER_CHANNEL = "com.nairitroy.optivus/email_launcher"
    private var initialPayload: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val extras = intent.extras
        val map = mutableMapOf<String, String>()
        if (extras != null && !extras.isEmpty) {
            for (key in extras.keySet()) {
                val value = extras.get(key)
                if (value != null) {
                    map[key] = value.toString()
                }
            }
        }
        val dataUri = intent.dataString
        if (dataUri != null && dataUri.isNotEmpty()) {
            map["dataUri"] = dataUri
        }
        if (map.isNotEmpty()) {
            initialPayload = map
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialNotificationPayload" -> {
                    result.success(initialPayload)
                }
                "clearInitialNotificationPayload" -> {
                    initialPayload = null
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMAIL_LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openEmailApp" -> {
                    try {
                        val emailIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_APP_EMAIL)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (emailIntent.resolveActivity(packageManager) != null) {
                            startActivity(emailIntent)
                            result.success(true)
                        } else {
                            val mailtoIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("mailto:")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            if (mailtoIntent.resolveActivity(packageManager) != null) {
                                startActivity(mailtoIntent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
