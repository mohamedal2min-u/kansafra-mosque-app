package org.kansafra.kansafra_mosque

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.kansafra.kansafra_mosque/adhan")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveSound") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || bytes == null) {
                    result.error("bad_args", "name and bytes are required", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(saveSound(name, bytes))
                } catch (e: Exception) {
                    result.error("save_failed", e.message, null)
                }
            }
    }

    /// يحفظ الصوت في مخزن الأصوات (Notifications/Kansafra) ليصل إليه النظام عند التنبيه.
    /// يعيد عنوان content:// أو null إن كان أندرويد أقدم من 10.
    private fun saveSound(name: String, bytes: ByteArray): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val displayName = "$name.mp3"
        // حذف نسخة سابقة بنفس الاسم حتى لا تتكرر.
        contentResolver.delete(
            collection,
            "${MediaStore.Audio.Media.DISPLAY_NAME}=? AND ${MediaStore.Audio.Media.RELATIVE_PATH} LIKE ?",
            arrayOf(displayName, "Notifications/Kansafra%")
        )
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/Kansafra")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(collection, values) ?: return null
        contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return null
        val done = ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }
        contentResolver.update(uri, done, null, null)
        return uri.toString()
    }
}
