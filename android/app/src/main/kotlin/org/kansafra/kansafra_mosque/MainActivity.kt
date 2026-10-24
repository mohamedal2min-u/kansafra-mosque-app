package org.kansafra.kansafra_mosque

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
                } else {
                    result.notImplemented()
                }
            }
    }
}
