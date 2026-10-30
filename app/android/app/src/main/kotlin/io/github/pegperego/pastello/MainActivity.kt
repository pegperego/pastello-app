package io.github.pegperego.pastello

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts Flutter and the system file pickers used to export and import the
 * drawings (ADR 0020): the parent chooses where the file goes, so the app
 * needs no storage permission.
 */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("busy", "A picker is already open", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    // Copies the file at "path" to a place the user chooses.
                    "save" -> {
                        pending = result
                        pendingFile = File(call.argument<String>("path")!!)
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType(ZIP)
                            .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        startActivityForResult(intent, SAVE)
                    }
                    // Copies a file the user chooses to "path".
                    "open" -> {
                        pending = result
                        pendingFile = File(call.argument<String>("path")!!)
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*")
                            .putExtra(Intent.EXTRA_MIME_TYPES, OPENABLE)
                        startActivityForResult(intent, OPEN)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE && requestCode != OPEN) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pending ?: return
        val file = pendingFile!!
        pending = null
        pendingFile = null
        val uri: Uri? = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        // Copying may take a while: off the main thread.
        Thread {
            try {
                if (requestCode == SAVE) {
                    contentResolver.openOutputStream(uri, "wt")!!.use { output ->
                        file.inputStream().use { it.copyTo(output) }
                    }
                } else {
                    contentResolver.openInputStream(uri)!!.use { input ->
                        file.outputStream().use { input.copyTo(it) }
                    }
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("io", e.message, null) }
            }
        }.start()
    }

    private companion object {
        const val CHANNEL = "io.github.pegperego.pastello/documents"
        const val SAVE = 4201
        const val OPEN = 4202
        const val ZIP = "application/zip"
        val OPENABLE = arrayOf(ZIP, "application/x-zip-compressed", "application/octet-stream")
    }
}
