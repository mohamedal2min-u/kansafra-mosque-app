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

  static const totalVerses = 6236;

  /// عدد الآيات قبل كل سورة (للترتيب المطلق للآية في المصحف).
  static List<int>? _prefix;

  /// ترتيب الآية في المصحف كله (1 إلى 6236).
  static int absIndex(int surah, int verse) {
    if (_prefix == null) {
      var acc = 0;
      _prefix = [
        for (var n = 1; n <= surahCount; n++)
          () {
            final before = acc;
            acc += verseCount(n);
            return before;
          }()
      ];
    }
    return _prefix![surah - 1] + verse;
  }

  /// بداية كل جزء: (سورة، آية).
  static const juzStarts = <(int, int)>[
    (1, 1),
    (2, 142),
    (2, 253),
    (3, 93),
    (4, 24),
    (4, 148),
    (5, 82),
    (6, 111),
    (7, 88),
    (8, 41),
    (9, 93),
    (11, 6),
    (12, 53),
    (15, 1),
    (17, 1),
    (18, 75),
    (21, 1),
    (23, 1),
    (25, 21),
    (27, 56),
    (29, 46),
    (33, 31),
    (36, 28),
    (39, 32),
    (41, 47),
    (46, 1),
    (51, 31),
    (58, 1),
    (67, 1),
    (78, 1),
  ];

  /// تطبيع للبحث: بلا تشكيل ولا علامات قرآنية ولا تطويل، وتوحيد الألف والياء والتاء المربوطة.
  static String normalize(String s) => s
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  static List<List<String>>? _normalized;

  /// بحث نصي في كل الآيات (حتى [limit] نتيجة). يعيد (سورة، آية).
  static List<(int, int)> search(String query, {int limit = 60}) {
    final q = normalize(query.trim());
    if (q.length < 2) return const [];
    _normalized ??= [
      for (var n = 1; n <= surahCount; n++)
        [for (var v = 1; v <= verseCount(n); v++) normalize(verse(n, v))]
    ];
    final out = <(int, int)>[];
    for (var n = 1; n <= surahCount && out.length < limit; n++) {
      final list = _normalized![n - 1];
      for (var v = 0; v < list.length && out.length < limit; v++) {
        if (list[v].contains(q)) out.add((n, v + 1));
      }
    }
    return out;
  }
}
