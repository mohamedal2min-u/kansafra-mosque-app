import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_calc.dart';

/// مكان سكن المستخدم خارج كنصفرة: الأذان يكون على توقيته، وتبقى مواقيت كنصفرة ظاهرة بجانبه.
/// يُحفظ على الهاتف فقط ولا يُرسَل لأي جهة.
class HomePlace {
  HomePlace._();

  static const _channel = MethodChannel('kansafra/launcher');
  static const _k = 'home_place_v1';
  static const _kDismissed = 'home_place_hint_dismissed';

  /// null = الأذان على توقيت كنصفرة.
  static final site = ValueNotifier<PrayerSite?>(null);

  /// الموقع المعتمد للأذان: مكان السكن إن حُدّد، وإلا المسجد.
  static PrayerSite get active => site.value ?? PrayerSite.mosque;

  static Future<void> load() async {
    final v = (await SharedPreferences.getInstance()).getString(_k);
    final p = v?.split('|');
    if (p == null || p.length != 3) return;
    final lat = double.tryParse(p[0]), lng = double.tryParse(p[1]);
    if (lat != null && lng != null) {
      site.value = PrayerSite.home(p[2], lat, lng);
    }
  }

  static Future<void> _save(PrayerSite? s) async {
    final prefs = await SharedPreferences.getInstance();
    if (s == null) {
      await prefs.remove(_k);
    } else {
      await prefs.setString(_k, '${s.latitude}|${s.longitude}|${s.name}');
    }
    site.value = s;
  }

  static Future<void> clear() => _save(null);

  /// الهاتف على توقيت غير توقيت سوريا: غالبًا مغترب، فنقترح عليه أذان مكان سكنه.
  static bool get looksAbroad =>
      DateTime.now().timeZoneOffset != PrayerCalc.offset;

  static Future<bool> hintDismissed() async =>
      (await SharedPreferences.getInstance()).getBool(_kDismissed) ?? false;

  static Future<void> dismissHint() async =>
      (await SharedPreferences.getInstance()).setBool(_kDismissed, true);

  /// يطلب إذن الموقع التقريبي ثم يحدّد مكان السكن. يعيد رسالة خطأ للمستخدم، أو null عند النجاح.
  static Future<String?> locate() async {
    if (kIsWeb) return 'تحديد الموقع متاح على الهاتف فقط.';
    final st = await Permission.locationWhenInUse.request();
    if (!st.isGranted) {
      if (st.isPermanentlyDenied) await openAppSettings();
      return 'لم يُسمح بالوصول إلى الموقع.';
    }
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('getLocation');
      final lat = (r?['lat'] as num?)?.toDouble();
      final lng = (r?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return 'تعذّر تحديد موقعك. حاول مجددًا.';
      final name = (r?['name'] as String?)?.trim();
      await _save(PrayerSite.home(
          name == null || name.isEmpty ? 'مكان سكني' : name, lat, lng));
      return null;
    } on PlatformException catch (e) {
      return e.code == 'location_off'
          ? 'شغّل خدمة الموقع في الهاتف ثم أعد المحاولة.'
          : 'تعذّر تحديد موقعك. حاول مجددًا.';
    }
  }

  /// عند فتح التطبيق: إن انتقل المستخدم أكثر من 30 كم (سفر) نحدّث المكان من آخر موقع يعرفه
  /// الهاتف، بلا تشغيل GPS ولا سؤال. يعيد true إن تغيّر المكان.
  static Future<bool> refreshQuietly() async {
    final s = site.value;
    if (kIsWeb || s == null) return false;
    try {
      if (!await Permission.locationWhenInUse.isGranted) return false;
      final r = await _channel
          .invokeMapMethod<String, dynamic>('getLocation', {'lastOnly': true});
      final lat = (r?['lat'] as num?)?.toDouble();
      final lng = (r?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;
      if (_km(s.latitude, s.longitude, lat, lng) < 30) return false;
      final name = (r?['name'] as String?)?.trim();
      await _save(PrayerSite.home(
          name == null || name.isEmpty ? 'مكان سكني' : name, lat, lng));
      return true;
    } catch (_) {
      return false;
    }
  }

  static double _km(double a1, double o1, double a2, double o2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final da = rad(a2 - a1), dl = rad(o2 - o1);
    final h = math.pow(math.sin(da / 2), 2) +
        math.cos(rad(a1)) * math.cos(rad(a2)) * math.pow(math.sin(dl / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
