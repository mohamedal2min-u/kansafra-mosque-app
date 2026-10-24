import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// نص المصحف (الرسم العثماني) مضمّن في التطبيق، فتعمل القراءة بدون إنترنت.
/// يُحمَّل مرة واحدة عند فتح تبويب القرآن، لا عند تشغيل التطبيق.
class QuranData {
  static List<Map<String, dynamic>>? _surahs;

  static Future<void> load() async {
    if (_surahs != null) return;
    final raw = await rootBundle.loadString('assets/quran.json');
    // التحليل في معالج منفصل حتى لا يتجمّد الرسم أثناء فتح تبويب القرآن.
    _surahs = await compute(_parse, raw);
  }

  static List<Map<String, dynamic>> _parse(String raw) =>
      (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  static const surahCount = 114;

  static Map<String, dynamic> _s(int n) => _surahs![n - 1];
  static String name(int n) => _s(n)['name'] as String;
  static bool isMakki(int n) => _s(n)['place'] == 'م';
  static int verseCount(int n) => (_s(n)['v'] as List).length;
  static String verse(int n, int v) => (_s(n)['v'] as List)[v - 1] as String;

  static String endMark(int v) {
    const d = '٠١٢٣٤٥٦٧٨٩';
    return '﴿${'$v'.split('').map((c) => d[int.parse(c)]).join()}﴾';
  }
}
