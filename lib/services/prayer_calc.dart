import 'package:adhan/adhan.dart';

import '../config.dart';

/// حساب مواقيت الصلاة لتاريخ معيّن مع تعديلات المسجد.
class PrayerCalc {
  static const names = {
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  static PrayerTimes forDate(DateTime date) {
    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi;
    final coords = Coordinates(MosqueConfig.latitude, MosqueConfig.longitude);
    return PrayerTimes(
      coords,
      DateComponents(date.year, date.month, date.day),
      params,
      utcOffset: const Duration(hours: 3),
    );
  }

  static DateTime adjusted(String key, DateTime t) =>
      t.add(Duration(minutes: MosqueConfig.minuteAdjustments[key] ?? 0));
}
