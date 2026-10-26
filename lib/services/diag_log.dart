import 'package:shared_preferences/shared_preferences.dart';

/// سجل أخطاء محلي صغير (آخر 30) يظهر في «تشخيص التطبيق» ليسهل تتبّع الأعطال على هاتف المستخدم.
class DiagLog {
  static const _key = 'diag_log_v1';
  static const _max = 30;

  static Future<void> add(String message) async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_key) ?? <String>[];
      final t = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceFirst('T', ' ');
      final m =
          message.length > 400 ? '${message.substring(0, 400)}…' : message;
      list.add('$t  $m');
      if (list.length > _max) list.removeRange(0, list.length - _max);
      await p.setStringList(_key, list);
    } catch (_) {}
  }

  /// الأحدث أولًا.
  static Future<List<String>> list() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_key) ?? const <String>[]).reversed.toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    try {
      (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}
