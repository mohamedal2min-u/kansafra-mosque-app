import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// وقت القراءة الفعلي في شاشة المصحف: يوميًا وإجماليًا، وأيام القراءة المتتالية. محفوظ على الهاتف.
class ReadingStats {
  ReadingStats._();
  static final instance = ReadingStats._();

  static const _kDays = 'read_days_v1';
  static const _kTotal = 'read_total_v1';
  static const _keepDays = 120;

  final Map<String, int> _days = {};
  int _total = 0;
  bool _loaded = false;
  bool _dirty = false;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  static String keyOf(DateTime d) => '${d.year}-${d.month}-${d.day}';

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
    _total = p.getInt(_kTotal) ?? _days.values.fold(0, (a, b) => a + b);
    _loaded = true;
  }

  /// يضيف ثواني قراءة اليوم. الكتابة على القرص دفعة كل نصف دقيقة تقريبًا لتوفير البطارية.
  Future<void> add(int seconds) async {
    await load();
    final k = keyOf(DateTime.now());
    _days[k] = (_days[k] ?? 0) + seconds;
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
    await p.setInt(_kTotal, _total);
  }

  int secondsOn(DateTime d) => _days[keyOf(d)] ?? 0;
  int get today => secondsOn(DateTime.now());
  int get total => _total;

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
}
