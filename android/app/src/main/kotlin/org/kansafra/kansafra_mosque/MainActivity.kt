package org.kansafra.kansafra_mosque

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import java.io.File
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // يفتح تطبيقًا مثبّتًا بحسب اسم حزمته (يرجع true إن فُتح).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kansafra/launcher")
            .setMethodCallHandler { call, result ->
                if (call.method == "openApp") {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val url = call.argument<String>("url")
                    for (pkg in packages) {
                        // إن وُجد رابط: افتحه داخل التطبيق نفسه مباشرة (رابط الدفع العميق).
                        val intent: Intent? = if (!url.isNullOrEmpty()) {
                            Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).setPackage(pkg)
                        } else {
                            packageManager.getLaunchIntentForPackage(pkg)
                        }
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            try {
                                startActivity(intent)
                                result.success(true)
                                return@setMethodCallHandler
                            } catch (e: Exception) {
                                // لا يوجد من يعالج الرابط: نجرّب فتح التطبيق فقط.
                                val plain = packageManager.getLaunchIntentForPackage(pkg)
                                if (plain != null) {
                                    plain.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(plain)
                                    result.success(true)
                                    return@setMethodCallHandler
                                }
                            }
                        }
                    }
                    result.success(false)
                } else if (call.method == "registerSound") {
                    // يسجّل ملف أذان محمَّل في MediaStore ليستطيع النظام تشغيله كصوت إشعار (content://).
                    val path = call.argument<String>("path") ?: ""
                    val title = call.argument<String>("title") ?: "أذان"
                    Thread {
                        try {
                            val uri = registerSound(path, title)
                            runOnUiThread { result.success(uri) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("register_failed", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun registerSound(path: String, title: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) throw IllegalStateException("يتطلب أندرويد 10 أو أحدث")
        val src = File(path)
        val name = src.name
        val resolver = contentResolver
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        resolver.query(collection, arrayOf(MediaStore.Audio.Media._ID),
            "${MediaStore.Audio.Media.DISPLAY_NAME}=?", arrayOf(name), null)?.use { c ->
            if (c.moveToFirst()) return ContentUris.withAppendedId(collection, c.getLong(0)).toString()
        }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.TITLE, title)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/Kansafra")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: throw IllegalStateException("تعذّر تسجيل الصوت")
        resolver.openOutputStream(uri)!!.use { out -> src.inputStream().use { it.copyTo(out) } }
        values.clear()
        values.put(MediaStore.Audio.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri.toString()
    }
}
