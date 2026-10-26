import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// وقت القراءة الفعلي في شاشة المصحف: يوميًا وإجماليًا، وأيام القراءة المتتالية. محفوظ على الهاتف.
class ReadingStats {
  ReadingStats._();
  static final instance = ReadingStats._();

  static const _kDays = 'read_days_v1';
  static const _kTotal = 'read_total_v1';
  static const _kMonths = 'read_months_v1';
  static const _keepDays = 400;

  final Map<String, int> _days = {}; // يومي (آخر 400 يوم)
  final Map<String, int> _months = {}; // شهري 'yyyy-m' (يُحفظ دائمًا)
  int _total = 0;
  bool _loaded = false;
  bool _dirty = false;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  static String keyOf(DateTime d) => '${d.year}-${d.month}-${d.day}';
  static String _monthKey(String dayKey) =>
      dayKey.substring(0, dayKey.lastIndexOf('-'));
  static String monthKeyOf(DateTime d) => '${d.year}-${d.month}';

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kDays);
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map)
            .forEach((k, v) => _days['$k'] = (v as num).toInt());
      } catch (_) {}
    }
    final rawM = p.getString(_kMonths);
    if (rawM != null) {
      try {
        (jsonDecode(rawM) as Map)
            .forEach((k, v) => _months['$k'] = (v as num).toInt());
      } catch (_) {}
    } else {
      // ترحيل من النسخة السابقة: نبني الشهور من الأيام المحفوظة.
      _days.forEach((k, v) {
        final mk = _monthKey(k);
        _months[mk] = (_months[mk] ?? 0) + v;
      });
    }
    _total = p.getInt(_kTotal) ?? _months.values.fold(0, (a, b) => a + b);
    _loaded = true;
  }

  /// يضيف ثواني قراءة اليوم. الكتابة على القرص دفعة كل نصف دقيقة تقريبًا لتوفير البطارية.
  Future<void> add(int seconds) async {
    await load();
    final k = keyOf(DateTime.now());
    _days[k] = (_days[k] ?? 0) + seconds;
    final mk = monthKeyOf(DateTime.now());
    _months[mk] = (_months[mk] ?? 0) + seconds;
    _total += seconds;
    _dirty = true;
    if (DateTime.now().difference(_lastFlush).inSeconds >= 30) await flush();
  }

  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    _lastFlush = DateTime.now();
    final cutoff = DateTime.now().subtract(const Duration(days: _keepDays));
    _days.removeWhere((k, _) {
      final parts = k.split('-').map(int.tryParse).toList();
      if (parts.length != 3 || parts.contains(null)) return true;
      return DateTime(parts[0]!, parts[1]!, parts[2]!).isBefore(cutoff);
    });
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDays, jsonEncode(_days));
    await p.setString(_kMonths, jsonEncode(_months));
    await p.setInt(_kTotal, _total);
  }

  int secondsOn(DateTime d) => _days[keyOf(d)] ?? 0;
  int get today => secondsOn(DateTime.now());
  int get total => _total;
  int get thisMonth => _months[monthKeyOf(DateTime.now())] ?? 0;
  int get thisYear => yearTotal(DateTime.now().year);

  int yearTotal(int year) {
    var sum = 0;
    _months.forEach((k, v) {
      if (k.startsWith('$year-')) sum += v;
    });
    return sum;
  }

  /// آخر [n] يومًا (الأحدث أولًا) مع ثواني كل يوم.
  List<MapEntry<DateTime, int>> lastDays(int n) {
    final now = DateTime.now();
    return [
      for (var i = 0; i < n; i++)
        MapEntry(DateTime(now.year, now.month, now.day - i),
            secondsOn(DateTime(now.year, now.month, now.day - i))),
    ];
  }

  /// كل الشهور المسجَّلة (الأحدث أولًا): (سنة، شهر) ← ثواني.
  List<MapEntry<(int, int), int>> get monthList {
    final out = <MapEntry<(int, int), int>>[];
    _months.forEach((k, v) {
      final p = k.split('-');
      out.add(MapEntry((int.parse(p[0]), int.parse(p[1])), v));
    });
    out.sort((a, b) => b.key.$1 != a.key.$1
        ? b.key.$1.compareTo(a.key.$1)
        : b.key.$2.compareTo(a.key.$2));
    return out;
  }

  /// كل السنوات المسجَّلة (الأحدث أولًا).
  List<MapEntry<int, int>> get yearList {
    final years = <int, int>{};
    for (final m in monthList) {
      years[m.key.$1] = (years[m.key.$1] ?? 0) + m.value;
    }
    return years.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  /// آخر 7 أيام (من الأقدم إلى اليوم).
  List<int> get lastWeek {
    final now = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--) secondsOn(now.subtract(Duration(days: i)))
    ];
  }

  int get week => lastWeek.fold(0, (a, b) => a + b);

  /// أيام متتالية بقراءة دقيقة فأكثر، تنتهي باليوم (أو بالأمس إن لم يقرأ اليوم بعد).
  int get streak {
    var d = DateTime.now();
    if (secondsOn(d) < 60) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (secondsOn(d) >= 60) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  static String format(int secs) {
    if (secs < 60) return secs == 0 ? '٠ دقيقة' : 'أقل من دقيقة';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h == 0) return '$m دقيقة';
    return m == 0 ? '$h ساعة' : '$h ساعة و$m دقيقة';
  }

  /// صيغة مختصرة للبطاقات الضيقة: «2 س 5 د».
  static String formatShort(int secs) {
    if (secs < 60) return secs == 0 ? '٠ د' : '< 1 د';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    return h == 0 ? '$m د' : (m == 0 ? '$h س' : '$h س $m د');
  }
}
