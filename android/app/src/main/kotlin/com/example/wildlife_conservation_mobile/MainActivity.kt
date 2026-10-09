package com.example.wildlife_conservation_mobile

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wildguard/reports")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSave != null) {
                    result.error("SAVE_IN_PROGRESS", "A document save is already open.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                if (bytes == null || name == null) {
                    result.error("INVALID_DOCUMENT", "The PDF is unavailable.", null)
                    return@setMethodCallHandler
                }
                pendingSave = result
                pendingBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, SAVE_PDF_REQUEST)
                } catch (exception: Exception) {
                    completeSaveError("Could not open the document picker.")
                }
            }
    }

    @Deprecated("Required for the platform document picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_PDF_REQUEST) return
        val result = pendingSave ?: return
        val bytes = pendingBytes
        try {
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result.success(null)
            } else {
                val output = contentResolver.openOutputStream(data.data!!)
                    ?: throw IllegalStateException("The destination could not be opened.")
                output.use { it.write(bytes ?: throw IllegalStateException("The PDF is unavailable.")) }
                result.success("PDF saved successfully.")
            }
        } catch (exception: Exception) {
            result.error("SAVE_FAILED", "The PDF could not be saved. Try another location.", null)
        } finally {
            pendingSave = null
            pendingBytes = null
        }
    }

    private fun completeSaveError(message: String) {
        pendingSave?.error("SAVE_FAILED", message, null)
        pendingSave = null
        pendingBytes = null
    }

    companion object {
        private const val SAVE_PDF_REQUEST = 2101
    }
}
