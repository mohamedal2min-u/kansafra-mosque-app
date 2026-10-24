import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';
import '../settings.dart';
import 'prayer_calc.dart';

/// جدولة تنبيه الأذان لخمس صلوات على مدى 7 أيام، وتُعاد الجدولة عند كل فتح للتطبيق.
class AdhanService {
  AdhanService._();
  static final instance = AdhanService._();

  static const _days = 7;
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(MosqueConfig.timeZone));

    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    await scheduleAll();
  }

  /// يجدول 7 أيام من التنبيهات. لا يعيد الجدولة (35 منبّهًا) عند كل فتح للتطبيق،
  /// بل عند تغيّر اليوم أو الإعدادات أو [force]: توفير للبطارية والمعالج.
  Future<void> scheduleAll({bool force = false}) async {
    final enabled = await AppSettings.adhanEnabled();
    final sound = await AppSettings.adhanChoice();
    final now0 = DateTime.now();
    final signature = '${now0.year}-${now0.month}-${now0.day}|$enabled|${sound.id}|'
        '${MosqueConfig.latitude},${MosqueConfig.longitude}|${MosqueConfig.minuteAdjustments}';
    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getString('sched_sig') == signature) return;

    await _plugin.cancelAll();
    await prefs.setString('sched_sig', signature);
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    var id = 0;
    for (var d = 0; d < _days; d++) {
      final day = now.add(Duration(days: d));
      final times = PrayerCalc.forDate(day);
      final list = {
        'fajr': times.fajr,
        'dhuhr': times.dhuhr,
        'asr': times.asr,
        'maghrib': times.maghrib,
        'isha': times.isha,
      };
      for (final e in list.entries) {
        final at = tz.TZDateTime.from(PrayerCalc.adjusted(e.key, e.value), tz.local);
        id++;
        if (at.isBefore(now)) continue;
        await _plugin.zonedSchedule(
          id,
          'حان الآن موعد أذان ${PrayerCalc.names[e.key]}',
          MosqueConfig.name,
          at,
          NotificationDetails(
            android: AndroidNotificationDetails(
              // صوت القناة لا يتغير بعد إنشائها، فلكل صوت قناة مستقلة.
              'adhan_${sound.id}',
              'الأذان (${sound.label})',
              channelDescription: 'تنبيهات أوقات الصلاة',
              importance: Importance.max,
              priority: Priority.high,
              sound: sound.rawName == null
                  ? null
                  : RawResourceAndroidNotificationSound(sound.rawName),
            ),
            iOS: const DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }
}
