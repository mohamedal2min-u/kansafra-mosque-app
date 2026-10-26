import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// كل نداءات أندرويد الأصلية (قناة واحدة kansafra/launcher).
class Launcher {
  static const _channel = MethodChannel('kansafra/launcher');

  /// الروابط الخارجية تعمل على الهاتف فقط.
  static bool get supported => !kIsWeb;

  /// يفتح [appUrl] (رابط التطبيق المباشر، مثل fb://) إن أمكن، وإلا الرابط في أول تطبيق
  /// مثبّت من [packages]، وإلا المتصفح.
  static Future<bool> openUrl(String url,
      {List<String> packages = const [], String? appUrl}) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl',
              {'url': url, 'packages': packages, 'appUrl': appUrl}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static bool _opening = false;

  /// يفتح الرابط مع إشارة فورية للمستخدم (تطبيق فيسبوك/ماسنجر قد يحتاج ثوانيَ ليفتح)،
  /// ويتجاهل الضغطات المتكررة أثناء الفتح.
  static Future<void> openWithFeedback(BuildContext context, String url,
      {List<String> packages = const [],
      String? appUrl,
      String label = 'الرابط'}) async {
    if (_opening) return;
    _opening = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
        content: Text('جارٍ فتح $label…'),
        duration: const Duration(seconds: 2)));
    try {
      final ok = await openUrl(url, packages: packages, appUrl: appUrl);
      if (!ok) {
        messenger.hideCurrentSnackBar();
        messenger
            .showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط.')));
      }
    } finally {
      // نمنع التكرار لحظات حتى يظهر التطبيق الآخر.
      Future.delayed(const Duration(seconds: 2), () => _opening = false);
    }
  }

  /// يفتح تطبيقًا مثبّتًا بحسب اسم حزمته، مع رابط اختياري داخله. يعيد true إن فُتح.
  static Future<bool> openApp(List<String> packages, {String? url}) async {
    try {
      return await _channel.invokeMethod<bool>(
              'openApp', {'packages': packages, 'url': url}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// قفل المعالج (و)الواي فاي أثناء تشغيل القرآن. يعيد true إن نجح النداء.
  static Future<bool> keepAwake(bool on, bool wifi) async {
    try {
      await _channel.invokeMethod('keepAwake', {'on': on, 'wifi': wifi});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// يسجّل ملف أذان في MediaStore ويعيد content:// ليستعمله النظام صوت إشعار.
  static Future<String?> registerSound(String path, String title) => _channel
      .invokeMethod<String>('registerSound', {'path': path, 'title': title});
}
