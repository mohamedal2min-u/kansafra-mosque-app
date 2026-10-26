import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';
import '../settings.dart';
import '../quran/khatma.dart';
import 'diag_log.dart';
import 'prayer_calc.dart';

/// جدولة تنبيه الأذان لخمس صلوات على مدى 7 أيام، وتُعاد الجدولة عند كل فتح للتطبيق.
class AdhanService {
  AdhanService._();
  static final instance = AdhanService._();

  static const _days = 7;
  final _plugin = FlutterLocalNotificationsPlugin();
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// حالة الأذونات المطلوبة لعمل الأذان والتطبيق مغلق (أندرويد فقط).
  Future<AdhanPermissions> permissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return const AdhanPermissions(true, true);
    return AdhanPermissions(
      await android.areNotificationsEnabled() ?? true,
      await android.canScheduleExactNotifications() ?? true,
    );
  }

  /// يطلب إذن الإشعارات، وإن كان مرفوضًا نهائيًا يفتح إعدادات التطبيق في الهاتف.
  Future<void> enableNotifications() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    if (!(await permissions()).notifications) await openAppSettings();
    await scheduleAll(force: true);
  }

  Future<void> enableExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
    await scheduleAll(force: true);
  }

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

    try {
      await scheduleAll();
    } catch (_) {
      // سُجّل الخطأ في DiagLog؛ لا نوقف بقية التهيئة.
    }
    await Khatma.instance.scheduleReminders();
  }

  /// تفاصيل الإشعار: لكل صوت قناة مستقلة لأن صوت القناة لا يتغير بعد إنشائها.
  NotificationDetails _details(AdhanChoice sound, String? raw) {
    final auto = sound.auto && sound.custom == null;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        auto ? 'adhan_auto_$raw' : 'adhan_${sound.id}',
        auto ? 'الأذان (تلقائي: $raw)' : 'الأذان (${sound.label})',
        channelDescription: 'تنبيهات أوقات الصلاة',
        importance: Importance.max,
        priority: Priority.high,
        // يُعامَل كمنبّه: يُسمَع بصوت المنبّه ويعمل والهاتف في وضع السكون.
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        sound: sound.custom != null
            ? UriAndroidNotificationSound(sound.custom!.uri)
            : raw == null
                ? null
                : RawResourceAndroidNotificationSound(raw),
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    );
  }

  /// إن رفض النظام التنبيه الدقيق (لم يُمنح الإذن) نجدول تنبيهًا غير دقيق بدل أن يفشل كل شيء.
  Future<void> _zoned(int id, String title, String body, tz.TZDateTime at,
      NotificationDetails details) async {
    for (final mode in const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return;
      } on PlatformException {
        if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
      }
    }
  }

  /// تنبيه تجريبي بعد [seconds] ثانية بالصوت المختار، للتأكد من أن الأذان يُسمع على هذا الهاتف.
  Future<void> scheduleTest({int seconds = 10}) async {
    final sound = await AppSettings.adhanChoice();
    final at = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    final raw = sound.rawNameFor('fajr', at.millisecondsSinceEpoch ~/ 86400000);
    await _zoned(9999, 'تجربة الأذان', 'هكذا سيُسمع التنبيه في وقت الصلاة', at,
        _details(sound, raw));
  }

  /// عدد الإشعارات المجدولة حاليًا في النظام (للتشخيص).
  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  /// يجدول 7 أيام من التنبيهات. لا يعيد الجدولة (35 منبّهًا) عند كل فتح للتطبيق،
  /// بل عند تغيّر اليوم أو الإعدادات أو [force]: توفير للبطارية والمعالج.
  /// لا نحفظ «بصمة» الجدولة إلا بعد نجاحها، فإن فشلت تُعاد المحاولة في الفتح التالي.
  Future<void> scheduleAll({bool force = false}) async {
    final enabled = await AppSettings.adhanEnabled();
    final sound = await AppSettings.adhanChoice();
    final now0 = DateTime.now();
    final signature =
        '${now0.year}-${now0.month}-${now0.day}|$enabled|${sound.id}|'
        '${MosqueConfig.latitude},${MosqueConfig.longitude}|${MosqueConfig.minuteAdjustments}';
    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getString('sched_sig') == signature) return;

    try {
      await _plugin.cancelAll();
      await prefs.remove('sched_sig');
      if (enabled) {
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
            final at = tz.TZDateTime.from(
                PrayerCalc.adjusted(e.key, e.value), tz.local);
            id++;
            if (at.isBefore(now)) continue;
            final raw =
                sound.rawNameFor(e.key, at.millisecondsSinceEpoch ~/ 86400000);
            await _zoned(id, 'حان الآن موعد أذان ${PrayerCalc.names[e.key]}',
                MosqueConfig.name, at, _details(sound, raw));
          }
        }
      }
      await prefs.setString('sched_sig', signature);
      await prefs.setString('sched_last_ok', DateTime.now().toIso8601String());
    } catch (e) {
      await DiagLog.add('جدولة الأذان فشلت: $e');
      rethrow;
    }
  }
}

class AdhanPermissions {
  final bool notifications;
  final bool exactAlarms;
  const AdhanPermissions(this.notifications, this.exactAlarms);
  bool get ok => notifications && exactAlarms;
}
