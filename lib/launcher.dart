import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// كل نداءات أندرويد الأصلية (قناة واحدة kansafra/launcher).
class Launcher {
  static const _channel = MethodChannel('kansafra/launcher');

  /// الروابط الخارجية تعمل على الهاتف فقط.
  static bool get supported => !kIsWeb;

  /// يفتح الرابط (تطبيق فيسبوك إن كان مثبّتًا، وإلا المتصفح).
  static Future<bool> openUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
    } catch (_) {
      return false;
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
