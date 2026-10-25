package org.kansafra.kansafra_mosque

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
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
                } else if (call.method == "keepAwake") {
                    // أثناء تشغيل القرآن: قفل معالج، وقفل واي فاي عند البثّ من الإنترنت (يُفلَت عند الإيقاف).
                    keepAwake(call.argument<Boolean>("on") == true, call.argument<Boolean>("wifi") == true)
                    result.success(null)
                } else if (call.method == "openUrl") {
                    val url = call.argument<String>("url") ?: ""
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
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

    companion object {
        // static: تبقى الأقفال صالحة حتى لو أُعيد إنشاء النشاط والخدمة ما زالت تعمل.
        private var wakeLock: PowerManager.WakeLock? = null
        private var wifiLock: WifiManager.WifiLock? = null
    }

    @Suppress("DEPRECATION")
    private fun keepAwake(on: Boolean, wifi: Boolean) {
        try {
            if (on) {
                if (wakeLock == null) {
                    val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "kansafra:quran").apply { setReferenceCounted(false) }
                }
                if (wakeLock?.isHeld != true) wakeLock?.acquire() // يُفلَت عند الإيقاف أو انتهاء القائمة (Dart)
                if (wifi) {
                    if (wifiLock == null) {
                        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "kansafra:quran").apply { setReferenceCounted(false) }
                    }
                    if (wifiLock?.isHeld != true) wifiLock?.acquire()
                } else if (wifiLock?.isHeld == true) {
                    wifiLock?.release()
                }
            } else {
                if (wakeLock?.isHeld == true) wakeLock?.release()
                if (wifiLock?.isHeld == true) wifiLock?.release()
            }
        } catch (e: Exception) {
            // لا نكسر التشغيل إن رفض النظام القفل.
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
