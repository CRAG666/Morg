package dev.morg.morg

import android.database.ContentObserver
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.morg/documents")
            .setMethodCallHandler { call, result ->
                if (call.method != "awaitChildren") return@setMethodCallHandler result.notImplemented()
                val directory = Uri.parse(call.argument<String>("uri"))
                thread {
                    try {
                        val changed = awaitChildren(directory)
                        runOnUiThread { result.success(changed) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("DocumentsError", error.message, null) }
                    }
                }
            }
    }

    // Cloud providers such as Google Drive answer from a cache and set EXTRA_LOADING while
    // they fetch the real listing, then notify the cursor's URI. DocumentsUI waits for that.
    private fun awaitChildren(directory: Uri): Boolean {
        val id =
            if (DocumentsContract.isDocumentUri(this, directory)) {
                DocumentsContract.getDocumentId(directory)
            } else {
                DocumentsContract.getTreeDocumentId(directory)
            }
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(directory, id)
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
        contentResolver.query(children, projection, null, null, null)?.use { cursor ->
            if (cursor.extras?.getBoolean(DocumentsContract.EXTRA_LOADING) != true) return false
            val loaded = CountDownLatch(1)
            val observer =
                object : ContentObserver(null) {
                    override fun onChange(selfChange: Boolean) = loaded.countDown()
                }
            contentResolver.registerContentObserver(cursor.notificationUri ?: children, true, observer)
            try {
                return loaded.await(LOADING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            } finally {
                contentResolver.unregisterContentObserver(observer)
            }
        }
        return false
    }

    private companion object {
        const val LOADING_TIMEOUT_SECONDS = 10L
    }
}
