package org.kansafra.kansafra_mosque

import android.annotation.SuppressLint
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.Context
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import java.io.File
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
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
                    // نجرّب التطبيق المناسب مباشرة (ماسنجر/فيسبوك) لتجنّب المرور بالمتصفح ثم التحويل، وهو بطيء.
                    val url = call.argument<String>("url") ?: ""
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val uri = android.net.Uri.parse(url)
                    var opened = false
                    for (pkg in packages + listOf("")) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            if (pkg.isNotEmpty()) intent.setPackage(pkg)
                            startActivity(intent)
                            opened = true
                            break
                        } catch (e: Exception) {
                            // التطبيق غير مثبّت أو لا يفتح هذا الرابط: نجرّب التالي.
                        }
                    }
                    result.success(opened)
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
                } else if (call.method == "getLocation") {
                    getLocation(call.argument<Boolean>("lastOnly") == true, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    /// موقع تقريبي لمواقيت مكان السكن: آخر موقع يعرفه الهاتف إن كان حديثًا، وإلا قراءة واحدة
    /// من الشبكة (بلا تتبّع مستمر). [lastOnly]: بلا أي قراءة جديدة (تحديث صامت عند الفتح).
    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun getLocation(lastOnly: Boolean, result: MethodChannel.Result) {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val replied = AtomicBoolean(false)
        fun reply(loc: Location?) {
            if (!replied.compareAndSet(false, true)) return
            if (loc == null) {
                runOnUiThread { result.error("no_location", "no location", null) }
                return
            }
            // اسم المدينة بالعربية (يحتاج إنترنت)، في خيط جانبي.
            Thread {
                var name: String? = null
                try {
                    val a = Geocoder(this, Locale("ar")).getFromLocation(loc.latitude, loc.longitude, 1)?.firstOrNull()
                    name = a?.locality ?: a?.subAdminArea ?: a?.adminArea ?: a?.countryName
                } catch (e: Exception) {
                    // بلا اسم: يظهر «مكان سكني».
                }
                runOnUiThread { result.success(mapOf("lat" to loc.latitude, "lng" to loc.longitude, "name" to name)) }
            }.start()
        }
        try {
            val last = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER, LocationManager.PASSIVE_PROVIDER)
                .mapNotNull { p -> try { lm.getLastKnownLocation(p) } catch (e: Exception) { null } }
                .maxByOrNull { it.time }
            if (lastOnly || (last != null && System.currentTimeMillis() - last.time < 6 * 3600_000L)) {
                reply(last)
                return
            }
            val provider = when {
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                else -> null
            }
            if (provider == null) {
                if (last != null) reply(last) else result.error("location_off", "location services off", null)
                return
            }
            val handler = Handler(Looper.getMainLooper())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val cancel = CancellationSignal()
                handler.postDelayed({ cancel.cancel(); reply(last) }, 20_000)
                lm.getCurrentLocation(provider, cancel, mainExecutor) { reply(it ?: last) }
            } else {
                val listener = object : LocationListener {
                    override fun onLocationChanged(loc: Location) { reply(loc) }
                    override fun onProviderDisabled(p: String) {}
                    override fun onProviderEnabled(p: String) {}
                    override fun onStatusChanged(p: String?, s: Int, b: android.os.Bundle?) {}
                }
                handler.postDelayed({ lm.removeUpdates(listener); reply(last) }, 20_000)
                lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            }
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) result.error("location_failed", e.message, null)
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

    /// يسجّل الملف في MediaStore ليقرأه النظام كصوت إشعار. يجرّب أكثر من مجلد/وسم لأن بعض الأجهزة
    /// ترفض مسارًا أو وسمًا دون آخر، ويجمع أسباب الفشل في رسالة واحدة.
    private fun registerSound(path: String, title: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) throw IllegalStateException("يتطلب أندرويد 10 أو أحدث")
        val src = File(path)
        if (!src.exists() || src.length() < 1000) throw IllegalStateException("الملف المحمَّل غير موجود أو تالف")
        val name = src.name
        val resolver = contentResolver
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        try {
            resolver.query(collection, arrayOf(MediaStore.Audio.Media._ID),
                "${MediaStore.Audio.Media.DISPLAY_NAME}=?", arrayOf(name), null)?.use { c ->
                if (c.moveToFirst()) return ContentUris.withAppendedId(collection, c.getLong(0)).toString()
            }
        } catch (e: Exception) {
            // نكمل بإدخال جديد.
        }
        val errors = ArrayList<String>()
        // (المجلد، هل يوسَم كنغمة إشعار)
        val attempts = listOf("Notifications/Kansafra" to true, "Notifications" to true, "Music/Kansafra" to false)
        for ((dir, flag) in attempts) {
            var uri: android.net.Uri? = null
            try {
                val values = ContentValues().apply {
                    put(MediaStore.Audio.Media.DISPLAY_NAME, name)
                    put(MediaStore.Audio.Media.TITLE, title)
                    put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
                    put(MediaStore.Audio.Media.RELATIVE_PATH, dir)
                    if (flag) put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                    put(MediaStore.Audio.Media.IS_PENDING, 1)
                }
                uri = resolver.insert(collection, values) ?: throw IllegalStateException("insert returned null")
                resolver.openOutputStream(uri)!!.use { out -> src.inputStream().use { it.copyTo(out) } }
                values.clear()
                values.put(MediaStore.Audio.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return uri.toString()
            } catch (e: Exception) {
                errors.add("$dir: ${e.javaClass.simpleName} ${e.message}")
                try { if (uri != null) resolver.delete(uri, null, null) } catch (_: Exception) {}
            }
        }
        throw IllegalStateException(errors.joinToString(" | "))
    }
}
