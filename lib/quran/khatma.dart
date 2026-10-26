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

class Khatma {
  Khatma._();
  static final instance = Khatma._();

  static const _kMark = 'khatma_mark';
  static const _kRemind = 'khatma_remind';
  static const _kHour = 'khatma_hour';
  static const _kMinute = 'khatma_minute';
  static const _kLastRead = 'khatma_last_read';
  static const _baseId = 7000; // معرّفات إشعارات الختمة (لا تتعارض مع الأذان)
  static const _days = 14;

  final mark = ValueNotifier<Bookmark?>(null);
  bool remind = true;
  TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);
  bool _loaded = false;

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
    _loaded = true;
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// وضع العلامة = قرأ اليوم، فلا يُذكَّر اليوم ويبدأ التذكير من الغد.
  Future<void> setMark(int surah, int verse) async {
    await load();
    mark.value = Bookmark(surah, verse);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMark, jsonEncode({'s': surah, 'v': verse}));
    await p.setString(_kLastRead, _today());
    await scheduleReminders();
  }

  Future<void> clearMark() async {
    await load();
    mark.value = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kMark);
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
    await scheduleReminders();
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
      final readToday = p.getString(_kLastRead) == _today();
      final now = tz.TZDateTime.now(tz.local);
      for (var d = 0; d < _days; d++) {
        final day = now.add(Duration(days: d));
        final at = tz.TZDateTime(
            tz.local, day.year, day.month, day.day, time.hour, time.minute);
        if (at.isBefore(now) || (d == 0 && readToday)) continue;
        await plugin.zonedSchedule(
          _baseId + d,
          'وردك اليومي من القرآن',
          'أكمل ختمتك من ${m.label}',
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
