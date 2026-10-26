import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../services/adhan_service.dart';
import 'quran_data.dart';

/// علامة الختمة: آخر آية وصل إليها القارئ، مع تذكير يومي لإكمال الورد.
class Bookmark {
  final int surah;
  final int verse;
  const Bookmark(this.surah, this.verse);

  String get label => 'سورة ${QuranData.name(surah)}، آية $verse';
}

class Khatma extends ChangeNotifier {
  Khatma._();
  static final instance = Khatma._();

  static const _kMark = 'khatma_mark';
  static const _kRemind = 'khatma_remind';
  static const _kHour = 'khatma_hour';
  static const _kMinute = 'khatma_minute';
  static const _kLastRead = 'khatma_last_read';
  static const _kGoalDays = 'khatma_goal_days';
  static const _kGoalStart = 'khatma_goal_start';
  static const _kDayStart =
      'khatma_day_start'; // 'تاريخ|موضع' أول اليوم لحساب ورد اليوم
  static const _baseId = 7000; // معرّفات إشعارات الختمة (لا تتعارض مع الأذان)
  static const _days = 14;

  final mark = ValueNotifier<Bookmark?>(null);
  bool remind = true;
  TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);
  bool _loaded = false;
  int? goalDays; // هدف: ختمة في كذا يومًا
  DateTime? goalStart;
  int _dayStartAbs = 0; // موضع القارئ في أول اليوم (ترتيب الآية في المصحف)

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kMark);
    if (raw != null) {
      try {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        mark.value = Bookmark(m['s'] as int, m['v'] as int);
      } catch (_) {}
    }
    remind = p.getBool(_kRemind) ?? true;
    time = TimeOfDay(
        hour: p.getInt(_kHour) ?? 20, minute: p.getInt(_kMinute) ?? 0);
    // نص السور مطلوب لعرض اسم السورة في العلامة وفي التذكير؛ نحمّله فقط إن وُجدت علامة.
    if (mark.value != null) await QuranData.load();
    final ds = (p.getString(_kDayStart) ?? '').split('|');
    if (ds.length == 2 && ds[0] == _today()) {
      _dayStartAbs = int.tryParse(ds[1]) ?? 0;
    } else {
      await _startDay(p, _abs(mark.value));
    }
    _loaded = true;
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static int _abs(Bookmark? b) =>
      b == null ? 0 : QuranData.absIndex(b.surah, b.verse);

  Future<void> _startDay(SharedPreferences p, int abs) async {
    _dayStartAbs = abs;
    await p.setString(_kDayStart, '${_today()}|$abs');
  }

  /// وضع العلامة = قرأ اليوم، فلا يُذكَّر اليوم ويبدأ التذكير من الغد.
  Future<void> setMark(int surah, int verse) async {
    await load();
    final p = await SharedPreferences.getInstance();
    // أول علامة في يوم جديد: يبدأ ورد اليوم من الموضع السابق (أو من هنا إن لم توجد علامة قبلها).
    final ds = (p.getString(_kDayStart) ?? '').split('|');
    if (ds.isEmpty || ds[0] != _today()) {
      await _startDay(
          p,
          mark.value == null
              ? QuranData.absIndex(surah, verse)
              : _abs(mark.value));
    } else if (mark.value == null) {
      await _startDay(p, QuranData.absIndex(surah, verse));
    }
    mark.value = Bookmark(surah, verse);
    await p.setString(_kMark, jsonEncode({'s': surah, 'v': verse}));
    await p.setString(_kLastRead, _today());
    notifyListeners();
    await scheduleReminders();
  }

  Future<void> clearMark() async {
    await load();
    mark.value = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kMark);
    notifyListeners();
    await scheduleReminders();
  }

  Future<void> setReminder({bool? on, TimeOfDay? at}) async {
    await load();
    if (on != null) remind = on;
    if (at != null) time = at;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRemind, remind);
    await p.setInt(_kHour, time.hour);
    await p.setInt(_kMinute, time.minute);
    notifyListeners();
    await scheduleReminders();
  }

  /// يحدد هدف الختمة بعدد الأيام ويبدأ العدّ من اليوم (null يلغي الهدف).
  Future<void> setGoal(int? days) async {
    await load();
    goalDays = days;
    goalStart = days == null ? null : DateTime.now();
    final p = await SharedPreferences.getInstance();
    if (days == null) {
      await p.remove(_kGoalDays);
      await p.remove(_kGoalStart);
    } else {
      await p.setInt(_kGoalDays, days);
      await p.setString(_kGoalStart, goalStart!.toIso8601String());
    }
    notifyListeners(); // لتتحدّث البطاقات
    await scheduleReminders();
  }

  /// نسبة ما قرأه من المصحف (0 إلى 1) بحسب موضع العلامة.
  double get progress {
    final m = mark.value;
    return m == null
        ? 0
        : QuranData.absIndex(m.surah, m.verse) / QuranData.totalVerses;
  }

  /// الأيام المتبقية من الهدف (لا تقل عن 1 ما دام الهدف قائمًا).
  int? get daysLeft {
    final d = goalDays, st = goalStart;
    if (d == null || st == null) return null;
    final today = DateTime.now();
    final elapsed = DateTime(today.year, today.month, today.day)
        .difference(DateTime(st.year, st.month, st.day))
        .inDays;
    final left = d - elapsed;
    return left < 1 ? 1 : left;
  }

  /// ورد اليوم: الآيات المطلوبة اليوم لإنهاء الهدف في موعده، محسوبة من موضعك أول اليوم
  /// (فلا يتغيّر الرقم وأنت تقرأ).
  int? get dailyVerses {
    final left = daysLeft;
    if (left == null) return null;
    if (_abs(mark.value) >= QuranData.totalVerses) return 0; // اكتملت الختمة
    final remaining = QuranData.totalVerses - _dayStartAbs;
    return remaining <= 0 ? 0 : (remaining / left).ceil();
  }

  /// كم آية قرأ اليوم (بحسب تقدّم العلامة منذ أول اليوم).
  int get readToday {
    final r = _abs(mark.value) - _dayStartAbs;
    return r < 0 ? 0 : r;
  }

  /// يجدول تذكيرًا لكل يوم من الأيام القادمة (14 يومًا) بوقت واحد، ويتخطى اليوم إن كان قد قرأ.
  /// يُعاد عند فتح التطبيق وعند كل تغيير. إشعار غير دقيق: لا يحتاج إذن المنبّه الدقيق ويوفّر البطارية.
  Future<void> scheduleReminders() async {
    try {
      await load();
      final plugin = AdhanService.instance.plugin;
      for (var d = 0; d < _days; d++) {
        await plugin.cancel(_baseId + d);
      }
      final m = mark.value;
      if (!remind || m == null) return;
      final p = await SharedPreferences.getInstance();
      final doneToday = p.getString(_kLastRead) == _today();
      // وقت التذكير بساعة الهاتف (عادة شخصية)، لا بتوقيت المسجد.
      final now = DateTime.now();
      for (var d = 0; d < _days; d++) {
        final local =
            DateTime(now.year, now.month, now.day + d, time.hour, time.minute);
        if (local.isBefore(now) || (d == 0 && doneToday)) continue;
        final at = tz.TZDateTime.from(local, tz.local);
        await plugin.zonedSchedule(
          _baseId + d,
          'وردك اليومي من القرآن',
          dailyVerses == null || dailyVerses == 0
              ? 'أكمل ختمتك من ${m.label}'
              : 'وردك اليوم نحو $dailyVerses آية. أكمل من ${m.label}',
          at,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'khatma_reminder',
              'تذكير الختمة',
              channelDescription: 'تذكير يومي لإكمال قراءة القرآن',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // لا نكسر القراءة إن تعذّرت الجدولة (مثلًا على الويب).
    }
  }
}
