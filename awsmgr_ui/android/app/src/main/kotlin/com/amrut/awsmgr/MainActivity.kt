package com.amrut.aethrops

import android.media.MediaScannerConnection
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.amrut.aethrops/media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path != null) {
                    scanFile(path, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Path is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun scanFile(path: String, result: MethodChannel.Result) {
        MediaScannerConnection.scanFile(
            this,
            arrayOf(path),
            null
        ) { scannedPath, uri ->
            if (uri != null) {
                result.success("File scanned: $scannedPath")
            } else {
                result.error("SCAN_FAILED", "Failed to scan file", null)
            }
        }
    }
}
