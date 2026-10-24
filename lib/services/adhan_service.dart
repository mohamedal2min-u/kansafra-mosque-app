import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';
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

  Future<void> scheduleAll() async {
    await _plugin.cancelAll();
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
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'adhan',
              'الأذان',
              channelDescription: 'تنبيهات أوقات الصلاة',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }
}
