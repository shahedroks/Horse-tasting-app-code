package com.example.test_project_glue_u

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {

    private val channelName = "com.example.test_project_glue_u/object_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "detectObject") {
                val bytes = when (val args = call.arguments) {
                    is ByteArray -> args
                    is ByteBuffer -> ByteArray(args.remaining()).also { args.get(it) }
                    is List<*> -> args.map { (it as? Number)?.toInt()?.toByte() ?: 0 }.toByteArray()
                    else -> null
                }
                if (bytes == null || bytes.isEmpty()) {
                    result.error("INVALID_ARGS", "Expected image bytes", null)
                    return@setMethodCallHandler
                }
                try {
                    val bounds = NativeObjectDetector.detect(bytes)
                    if (bounds == null) {
                        result.success(null)
                    } else {
                        result.success(mapOf(
                            "centerX" to bounds.centerX,
                            "centerY" to bounds.centerY,
                            "halfWidth" to bounds.halfWidth,
                            "halfHeight" to bounds.halfHeight
                        ))
                    }
                } catch (e: Exception) {
                    result.error("DETECT_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
